use anyhow::{Context, Result};
use serde_json::Value;
use std::collections::HashMap;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::Path;
use std::time::{Duration, Instant};

pub mod config;
pub mod db;
pub mod parser;

use config::Config;
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
        let reader = BufReader::new(file);
        self.load_reader(reader)
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

    fn load_reader<R: BufRead>(&mut self, reader: R) -> Result<LoadStats> {
        let start_total = Instant::now();
        let mut start_chunk = Instant::now();
        let mut buffer: Vec<(String, HashMap<String, String>)> = Vec::new();
        let mut inserted_lines = 0;
        let mut total_db_duration = Duration::new(0, 0);

        for (idx, line) in reader.lines().enumerate() {
            let line = line?;
            let line_no = idx + 1;
            if line.trim().is_empty() {
                continue;
            }
            let json_value = Self::parse_json_line(&line);
            let row = self.build_row(&json_value, &line, line_no);
            buffer.push((line, row));
            if buffer.len() >= 1000 {
                self.flush_batch(
                    &mut buffer,
                    &mut total_db_duration,
                    &mut inserted_lines,
                    &mut start_chunk,
                )?;
            }
        }

        if !buffer.is_empty() {
            self.flush_batch(
                &mut buffer,
                &mut total_db_duration,
                &mut inserted_lines,
                &mut start_chunk,
            )?;
        }

        let fts_start = Instant::now();
        self.db.rebuild_fts()?;
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
