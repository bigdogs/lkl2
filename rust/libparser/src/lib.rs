use anyhow::{Context, Result};
use serde_json::Value;
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom};
use std::path::Path;
use std::time::{Duration, Instant};

pub mod config;
pub mod constants;
pub mod db;
pub mod parser;

pub use config::Config;
use constants::{BATCH_SIZE, FTS_BATCH_SIZE};
use db::Db;

pub struct LoadStats {
    pub inserted_lines: usize,
    pub total_duration: Duration,
    pub read_duration: Duration,
    pub db_duration: Duration,
    pub fts_duration: Duration,
}

pub struct QueryResult {
    pub headers: Vec<String>,
    pub rows: Vec<Vec<String>>,
    pub duration: Duration,
}

/// Phase of the file processing pipeline, reported via progress callbacks.
#[derive(Clone, Debug, PartialEq)]
pub enum LoadPhase {
    /// Reading file lines and inserting into the database.
    Reading,
    /// Building incremental FTS5 indexes.
    Indexing,
}

/// A single progress report from the loading pipeline.
#[derive(Clone, Debug)]
pub struct LoadProgress {
    pub phase: LoadPhase,
    /// 0.0 – 1.0
    pub progress: f64,
    /// Number of items processed so far in the current phase.
    pub processed_count: u64,
}

pub struct Engine {
    config: Config,
    db: Db,
}

impl Engine {
    pub fn from_embedded_config() -> Result<Self> {
        let config = Config::load().context("Failed to load config")?;
        Self::new(config)
    }

    pub fn new(config: Config) -> Result<Self> {
        let db = Db::new(&config).context("Failed to initialize DB")?;
        Ok(Self { config, db })
    }

    pub fn columns(&self) -> Vec<String> {
        let mut all_columns = Vec::with_capacity(self.db.columns.len() + 2);
        all_columns.push("id".to_string());
        all_columns.push("raw".to_string());
        all_columns.extend(self.db.columns.clone());
        all_columns
    }

    pub fn load_file<P: AsRef<Path>>(&mut self, path: P) -> Result<LoadStats> {
        let file = File::open(&path)
            .with_context(|| format!("Failed to open file {:?}", path.as_ref()))?;
        let total_bytes = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
        let reader = BufReader::new(file);
        self.load_reader(reader, total_bytes, false, &mut |_| {})
    }

    /// Load a file with optional tail-truncation and progress reporting.
    ///
    /// * `max_bytes` – if `Some(n)` and the file is larger than `n`, only the
    ///   last `n` bytes are loaded (the first partial line is discarded).
    /// * `on_progress` – called after every batch during both reading and
    ///   indexing phases.  The callback receives a `LoadProgress`.
    ///   Between calls the engine's `db` is in a consistent state so that
    ///   other threads may query it (the caller is responsible for yielding
    ///   the lock).
    pub fn load_file_progressive<P, F>(
        &mut self,
        path: P,
        max_bytes: Option<u64>,
        on_progress: &mut F,
    ) -> Result<(LoadStats, bool)>
    where
        P: AsRef<Path>,
        F: FnMut(LoadProgress),
    {
        let file_size = fs::metadata(&path)
            .with_context(|| format!("Failed to stat file {:?}", path.as_ref()))?
            .len();

        let mut file = File::open(&path)
            .with_context(|| format!("Failed to open file {:?}", path.as_ref()))?;

        let truncated = match max_bytes {
            Some(max) if file_size > max => {
                let skip_pos = file_size - max;
                file.seek(SeekFrom::Start(skip_pos))?;
                // Discard the first (likely partial) line.
                let mut discard = Vec::new();
                let mut one_byte = [0u8; 1];
                loop {
                    let n = file.read(&mut one_byte)?;
                    if n == 0 || one_byte[0] == b'\n' {
                        break;
                    }
                    discard.push(one_byte[0]);
                }
                true
            }
            _ => false,
        };

        let effective_size = if truncated {
            max_bytes.unwrap_or(file_size)
        } else {
            file_size
        };

        let reader = BufReader::new(file);
        let stats = self.load_reader(reader, effective_size, truncated, on_progress)?;
        Ok((stats, truncated))
    }

    pub fn execute_query(&self, query: &str) -> Result<QueryResult> {
        let start = Instant::now();
        let mut stmt = self.db.conn.prepare(query)?;
        let headers: Vec<String> = stmt.column_names().iter().map(|s| s.to_string()).collect();
        let mut rows_iter = stmt.query([])?;
        let mut rows = Vec::new();

        while let Some(row) = rows_iter.next()? {
            let mut values = Vec::with_capacity(headers.len());
            for i in 0..headers.len() {
                let value = row.get_ref(i)?;
                let val_str = match value {
                    rusqlite::types::ValueRef::Null => "NULL".to_string(),
                    rusqlite::types::ValueRef::Integer(i) => i.to_string(),
                    rusqlite::types::ValueRef::Real(f) => f.to_string(),
                    rusqlite::types::ValueRef::Text(t) => String::from_utf8_lossy(t).to_string(),
                    rusqlite::types::ValueRef::Blob(_) => "[BLOB]".to_string(),
                };
                values.push(val_str);
            }
            rows.push(values);
        }

        Ok(QueryResult {
            headers,
            rows,
            duration: start.elapsed(),
        })
    }

    fn load_reader<R, F>(
        &mut self,
        reader: R,
        total_bytes: u64,
        truncated: bool,
        on_progress: &mut F,
    ) -> Result<LoadStats>
    where
        R: BufRead,
        F: FnMut(LoadProgress),
    {
        let start_total = Instant::now();
        let mut start_chunk = Instant::now();
        let mut buffer: Vec<(String, HashMap<String, String>)> = Vec::new();
        let mut inserted_lines: usize = 0;
        let mut total_db_duration = Duration::new(0, 0);
        let mut bytes_read: u64 = 0;

        for (idx, line) in reader.lines().enumerate() {
            let line = line?;
            if line.trim().is_empty() {
                bytes_read += line.len() as u64 + 1;
                continue;
            }
            bytes_read += line.len() as u64 + 1;

            let json_value = Self::parse_json_line(&line);
            let line_no = if truncated { 0 } else { idx + 1 };
            let row = self.build_row(&json_value, &line, line_no);
            buffer.push((line, row));

            if buffer.len() >= BATCH_SIZE {
                self.flush_batch(
                    &mut buffer,
                    &mut total_db_duration,
                    &mut inserted_lines,
                    &mut start_chunk,
                )?;

                let progress = if total_bytes > 0 {
                    (bytes_read as f64 / total_bytes as f64).min(1.0)
                } else {
                    0.0
                };
                on_progress(LoadProgress {
                    phase: LoadPhase::Reading,
                    progress,
                    processed_count: inserted_lines as u64,
                });
            }
        }

        if !buffer.is_empty() {
            self.flush_batch(
                &mut buffer,
                &mut total_db_duration,
                &mut inserted_lines,
                &mut start_chunk,
            )?;
            on_progress(LoadProgress {
                phase: LoadPhase::Reading,
                progress: 1.0,
                processed_count: inserted_lines as u64,
            });
        }

        // --- Incremental FTS indexing ---
        let fts_start = Instant::now();
        let total_rows = self.db.get_row_count()?;
        let mut indexed: i64 = 0;
        while indexed < total_rows {
            self.db.index_fts_batch(indexed, FTS_BATCH_SIZE)?;
            indexed = (indexed + FTS_BATCH_SIZE).min(total_rows);
            let progress = if total_rows > 0 {
                (indexed as f64 / total_rows as f64).min(1.0)
            } else {
                1.0
            };
            on_progress(LoadProgress {
                phase: LoadPhase::Indexing,
                progress,
                processed_count: indexed as u64,
            });
        }
        let fts_duration = fts_start.elapsed();
        total_db_duration += fts_duration;

        let total_duration = start_total.elapsed();
        let read_duration = total_duration.saturating_sub(total_db_duration);

        Ok(LoadStats {
            inserted_lines,
            total_duration,
            read_duration,
            fts_duration,
            db_duration: total_db_duration,
        })
    }

    fn parse_json_line(line: &str) -> Value {
        match serde_json::from_str(line) {
            Ok(value) => value,
            Err(_) => Value::Null,
        }
    }

    fn build_row(&self, json_value: &Value, line: &str, line_no: usize) -> HashMap<String, String> {
        let mut row = HashMap::new();
        for (col, path) in &self.config.logs {
            let val = parser::extract_field(json_value, path, line, line_no);
            row.insert(col.clone(), val);
        }
        row
    }

    fn flush_batch(
        &mut self,
        buffer: &mut Vec<(String, HashMap<String, String>)>,
        total_db_duration: &mut Duration,
        inserted_lines: &mut usize,
        start_chunk: &mut Instant,
    ) -> Result<()> {
        let db_start = Instant::now();
        self.db.insert_batch(buffer)?;
        let db_duration = db_start.elapsed();
        *total_db_duration += db_duration;
        *inserted_lines += buffer.len();
        buffer.clear();
        let total_duration = start_chunk.elapsed();
        let read_duration = total_duration.saturating_sub(db_duration);
        log::info!(
            "Loaded {} lines. Read {:?}, SQLite {:?}, Total {:?}",
            inserted_lines,
            read_duration,
            db_duration,
            total_duration
        );
        *start_chunk = Instant::now();
        Ok(())
    }
}
