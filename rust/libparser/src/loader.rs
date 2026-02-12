use anyhow::{Context, Result};
use serde_json::Value;
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom};
use std::path::Path;
use std::time::{Duration, Instant};

use crate::constants::{BATCH_SIZE, FTS_BATCH_SIZE};
use crate::engine::Engine;
use crate::parser;
use crate::{LoadPhase, LoadProgress, LoadStats};

impl Engine {
    pub fn load_file<P: AsRef<Path>>(&mut self, path: P) -> Result<LoadStats> {
        let file = File::open(&path)
            .with_context(|| format!("Failed to open file {:?}", path.as_ref()))?;
        let total_bytes = fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
        let reader = BufReader::new(file);
        self.load_reader(reader, total_bytes, false, &mut |_| true)
    }

    /// Load a file with optional tail-truncation and progress reporting.
    ///
    /// * `max_bytes` – if `Some(n)` and the file is larger than `n`, only the
    ///   last `n` bytes are loaded (the first partial line is discarded).
    /// * `on_progress` – called after every batch.  Between calls the engine's
    ///   `db` is in a consistent state so other threads may query it.
    /// Load a file with optional tail-truncation and progress reporting.
    ///
    /// * `max_bytes` – if `Some(n)` and the file is larger than `n`, only the
    ///   last `n` bytes are loaded (the first partial line is discarded).
    /// * `on_progress` – called after every batch.  Return `true` to continue
    ///   loading, or `false` to cancel early.
    pub fn load_file_progressive<P, F>(
        &mut self,
        path: P,
        max_bytes: Option<u64>,
        on_progress: &mut F,
    ) -> Result<(LoadStats, bool)>
    where
        P: AsRef<Path>,
        F: FnMut(LoadProgress) -> bool,
    {
        let file_size = fs::metadata(&path)
            .with_context(|| format!("Failed to stat file {:?}", path.as_ref()))?
            .len();
        let mut file = File::open(&path)
            .with_context(|| format!("Failed to open file {:?}", path.as_ref()))?;

        let truncated = Self::maybe_seek_tail(&mut file, file_size, max_bytes)?;
        let effective_size = if truncated {
            max_bytes.unwrap_or(file_size)
        } else {
            file_size
        };

        let reader = BufReader::new(file);
        let stats = self.load_reader(reader, effective_size, truncated, on_progress)?;
        Ok((stats, truncated))
    }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------
impl Engine {
    /// If the file exceeds `max_bytes`, seek to `file_size - max_bytes` and
    /// discard the first partial line.  Returns `true` when truncation occurred.
    fn maybe_seek_tail(
        file: &mut File,
        file_size: u64,
        max_bytes: Option<u64>,
    ) -> Result<bool> {
        match max_bytes {
            Some(max) if file_size > max => {
                file.seek(SeekFrom::Start(file_size - max))?;
                // Discard the first (likely partial) line.
                let mut one_byte = [0u8; 1];
                loop {
                    let n = file.read(&mut one_byte)?;
                    if n == 0 || one_byte[0] == b'\n' {
                        break;
                    }
                }
                Ok(true)
            }
            _ => Ok(false),
        }
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
        F: FnMut(LoadProgress) -> bool,
    {
        let start_total = Instant::now();
        let (inserted_lines, db_duration) =
            self.read_and_insert(reader, total_bytes, truncated, on_progress)?;
        let fts_duration = self.build_fts_index(on_progress)?;

        let total_duration = start_total.elapsed();
        let read_duration = total_duration.saturating_sub(db_duration + fts_duration);

        Ok(LoadStats {
            inserted_lines,
            total_duration,
            read_duration,
            db_duration: db_duration + fts_duration,
            fts_duration,
        })
    }

    /// Read lines from the reader, parse JSON, build rows, and insert in batches.
    /// Returns (inserted_line_count, cumulative_db_duration).
    fn read_and_insert<R, F>(
        &mut self,
        reader: R,
        total_bytes: u64,
        truncated: bool,
        on_progress: &mut F,
    ) -> Result<(usize, Duration)>
    where
        R: BufRead,
        F: FnMut(LoadProgress) -> bool,
    {
        let mut buffer: Vec<(String, HashMap<String, String>)> = Vec::new();
        let mut inserted_lines: usize = 0;
        let mut db_duration = Duration::ZERO;
        let mut bytes_read: u64 = 0;

        for (idx, line) in reader.lines().enumerate() {
            let line = line?;
            bytes_read += line.len() as u64 + 1;
            if line.trim().is_empty() {
                continue;
            }

            let json_value = Self::parse_json_line(&line);
            let line_no = if truncated { 0 } else { idx + 1 };
            let row = self.build_row(&json_value, &line, line_no);
            buffer.push((line, row));

            if buffer.len() >= BATCH_SIZE {
                db_duration += self.flush_batch(&mut buffer, &mut inserted_lines)?;
                if !Self::report_reading_progress(
                    on_progress,
                    bytes_read,
                    total_bytes,
                    inserted_lines,
                ) {
                    anyhow::bail!("loading cancelled");
                }
            }
        }

        if !buffer.is_empty() {
            db_duration += self.flush_batch(&mut buffer, &mut inserted_lines)?;
            Self::report_reading_progress(on_progress, total_bytes, total_bytes, inserted_lines);
        }

        Ok((inserted_lines, db_duration))
    }

    /// Incrementally build the FTS5 index in batches.  Returns FTS duration.
    fn build_fts_index<F>(&mut self, on_progress: &mut F) -> Result<Duration>
    where
        F: FnMut(LoadProgress) -> bool,
    {
        let start = Instant::now();
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
            let keep_going = on_progress(LoadProgress {
                phase: LoadPhase::Indexing,
                progress,
                processed_count: indexed as u64,
            });
            if !keep_going {
                anyhow::bail!("loading cancelled");
            }
        }

        Ok(start.elapsed())
    }

    /// Report reading progress. Returns the callback's return value
    /// (`true` = continue, `false` = cancel).
    fn report_reading_progress<F>(
        on_progress: &mut F,
        bytes_read: u64,
        total_bytes: u64,
        inserted_lines: usize,
    ) -> bool
    where
        F: FnMut(LoadProgress) -> bool,
    {
        let progress = if total_bytes > 0 {
            (bytes_read as f64 / total_bytes as f64).min(1.0)
        } else {
            0.0
        };
        on_progress(LoadProgress {
            phase: LoadPhase::Reading,
            progress,
            processed_count: inserted_lines as u64,
        })
    }

    fn parse_json_line(line: &str) -> Value {
        serde_json::from_str(line).unwrap_or(Value::Null)
    }

    fn build_row(
        &self,
        json_value: &Value,
        line: &str,
        line_no: usize,
    ) -> HashMap<String, String> {
        self.config
            .logs
            .iter()
            .map(|(col, path)| {
                (col.clone(), parser::extract_field(json_value, path, line, line_no))
            })
            .collect()
    }

    /// Insert a batch into the DB.  Returns the time spent on the DB write.
    fn flush_batch(
        &mut self,
        buffer: &mut Vec<(String, HashMap<String, String>)>,
        inserted_lines: &mut usize,
    ) -> Result<Duration> {
        let start = Instant::now();
        self.db.insert_batch(buffer)?;
        *inserted_lines += buffer.len();
        let elapsed = start.elapsed();
        log::info!("Flushed {} lines in {:?}", buffer.len(), elapsed);
        buffer.clear();
        Ok(elapsed)
    }
}
