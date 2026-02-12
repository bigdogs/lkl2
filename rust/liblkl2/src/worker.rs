use anyhow::{bail, Context, Result};
use libparser::constants::{BATCH_SIZE, FTS_BATCH_SIZE};
use libparser::{Config, Engine, QueryResult};
use once_cell::sync::Lazy;
use parking_lot::Mutex;
use serde_json::Value;
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

// ---------------------------------------------------------------------------
// FileStatus — the observable state of a file-loading lifecycle.
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq)]
pub enum FileStatus {
    Uninit,
    Loading {
        phase: String,
        progress: f64,
        loaded_count: u64,
    },
    Complete {
        total_count: u64,
        truncated: bool,
    },
    Error(String),
}

// ---------------------------------------------------------------------------
// WorkerInstance — one per open_file(), self-contained lifecycle.
// ---------------------------------------------------------------------------

/// A single loading session.  Owns its own status (lightweight lock) and
/// engine (heavyweight lock).
///
/// The loading thread drives I/O and parsing **without** holding the engine
/// lock.  It only acquires the lock briefly for DB writes (`insert_batch`,
/// `index_fts_batch`), then releases it and yields so query threads are
/// never starved.
struct WorkerInstance {
    /// Lightweight lock — only for the UI-visible status.
    status: Mutex<FileStatus>,
    /// Heavyweight lock — held **only** during DB read/write operations.
    engine: Mutex<Option<Engine>>,
    /// Set to `true` when this instance is superseded by a newer one.
    cancelled: AtomicBool,
}

impl WorkerInstance {
    fn new() -> Arc<Self> {
        Arc::new(Self {
            status: Mutex::new(FileStatus::Uninit),
            engine: Mutex::new(None),
            cancelled: AtomicBool::new(false),
        })
    }

    fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Acquire)
    }

    fn cancel(&self) {
        self.cancelled.store(true, Ordering::Release);
    }

    // -- Status helpers -----------------------------------------------------

    fn set_status(&self, new_status: FileStatus) {
        *self.status.lock() = new_status;
    }

    fn get_status(&self) -> FileStatus {
        self.status.lock().clone()
    }

    // -- Loading ------------------------------------------------------------

    /// Start the background load.  The thread holds an `Arc` so that the
    /// instance stays alive until loading finishes (or is cancelled).
    fn start_load(self: &Arc<Self>, path: String, max_file_size: Option<u64>) {
        let inst = Arc::clone(self);
        thread::Builder::new()
            .name("lkl2-loader".into())
            .spawn(move || {
                let result = inst.run_load(&path, max_file_size);
                if !inst.is_cancelled() {
                    match result {
                        Ok((total_count, truncated)) => {
                            inst.set_status(FileStatus::Complete {
                                total_count,
                                truncated,
                            });
                        }
                        Err(e) => {
                            inst.set_status(FileStatus::Error(e.to_string()));
                        }
                    }
                }
                log::info!(
                    "Loader thread exiting (cancelled={})",
                    inst.is_cancelled()
                );
            })
            // Worker thread creation is critical; if it fails the
            // application cannot function.
            .expect("failed to spawn loader thread");
    }

    /// Blocking load — runs on the loader thread.
    ///
    /// File I/O and JSON parsing happen **without** holding the engine lock.
    /// The lock is acquired only for `insert_batch` / `index_fts_batch`,
    /// then released immediately.  A `thread::yield_now()` follows each
    /// progress report so query threads are not starved.
    fn run_load(&self, path: &str, max_bytes: Option<u64>) -> Result<(u64, bool)> {
        let start_total = Instant::now();

        // -- Create engine and store it immediately so queries see partial data.
        let config = Config::load()?;
        let engine = Engine::new(config.clone())?;
        *self.engine.lock() = Some(engine);

        // -- Open file and handle tail-truncation (no lock needed).
        let file_size = fs::metadata(path)
            .with_context(|| format!("Failed to stat file {:?}", path))?
            .len();
        let mut file = File::open(path)
            .with_context(|| format!("Failed to open file {:?}", path))?;

        let truncated = Self::maybe_seek_tail(&mut file, file_size, max_bytes)?;
        let total_bytes = if truncated {
            max_bytes.unwrap_or(file_size)
        } else {
            file_size
        };

        // -- Phase 1: read lines → parse → batch insert ----------------------
        let (inserted_lines, db_duration) =
            self.read_and_insert(&config, BufReader::new(file), total_bytes, truncated)?;

        // -- Phase 2: incremental FTS indexing --------------------------------
        let fts_duration = self.build_fts_index()?;

        let total_duration = start_total.elapsed();
        let read_duration = total_duration.saturating_sub(db_duration + fts_duration);
        log::info!(
            "File loaded: {} lines in {:?} (read {:?}, db {:?}, fts {:?}), truncated={}",
            inserted_lines,
            total_duration,
            read_duration,
            db_duration + fts_duration,
            fts_duration,
            truncated,
        );
        Ok((inserted_lines as u64, truncated))
    }

    // -- Phase 1: reading & inserting -----------------------------------------

    fn read_and_insert<R: BufRead>(
        &self,
        config: &Config,
        reader: R,
        total_bytes: u64,
        truncated: bool,
    ) -> Result<(usize, Duration)> {
        let mut buffer: Vec<(String, HashMap<String, String>)> = Vec::new();
        let mut inserted_lines: usize = 0;
        let mut db_duration = Duration::ZERO;
        let mut bytes_read: u64 = 0;

        for (idx, line) in reader.lines().enumerate() {
            if self.is_cancelled() {
                bail!("loading cancelled");
            }

            let line = line?;
            bytes_read += line.len() as u64 + 1;
            if line.trim().is_empty() {
                continue;
            }

            // Parse & build row — no engine lock needed.
            let json_value: Value =
                serde_json::from_str(&line).unwrap_or(Value::Null);
            let line_no = if truncated { 0 } else { idx + 1 };
            let row = Self::build_row(config, &json_value, &line, line_no);
            buffer.push((line, row));

            if buffer.len() >= BATCH_SIZE {
                // Lock engine **only** for the DB write.
                db_duration += self.flush_batch(&mut buffer, &mut inserted_lines)?;

                self.report_reading_progress(bytes_read, total_bytes, inserted_lines);
                log::info!(
                    "[reading] progress={:.1}% lines={} bytes={}/{}",
                    bytes_read as f64 / total_bytes.max(1) as f64 * 100.0,
                    inserted_lines,
                    bytes_read,
                    total_bytes,
                );
                thread::yield_now();
            }
        }

        // Flush remaining rows.
        if !buffer.is_empty() {
            db_duration += self.flush_batch(&mut buffer, &mut inserted_lines)?;
            self.report_reading_progress(total_bytes, total_bytes, inserted_lines);
            log::info!(
                "[reading] progress=100.0% lines={} bytes={}/{}",
                inserted_lines,
                total_bytes,
                total_bytes,
            );
            thread::yield_now();
        }

        Ok((inserted_lines, db_duration))
    }

    /// Lock the engine, insert a batch, unlock.
    fn flush_batch(
        &self,
        buffer: &mut Vec<(String, HashMap<String, String>)>,
        inserted_lines: &mut usize,
    ) -> Result<Duration> {
        let start = Instant::now();
        {
            let mut guard = self.engine.lock();
            let engine = guard.as_mut().context("engine not initialised")?;
            engine.insert_batch(buffer)?;
        }
        *inserted_lines += buffer.len();
        let elapsed = start.elapsed();
        buffer.clear();
        Ok(elapsed)
    }

    // -- Phase 2: FTS indexing ------------------------------------------------

    fn build_fts_index(&self) -> Result<Duration> {
        let start = Instant::now();
        let total_rows = {
            let guard = self.engine.lock();
            let engine = guard.as_ref().context("engine not initialised")?;
            engine.get_row_count()?
        };

        let mut indexed: i64 = 0;
        while indexed < total_rows {
            if self.is_cancelled() {
                bail!("loading cancelled");
            }

            // Lock only for the index batch.
            {
                let guard = self.engine.lock();
                let engine = guard.as_ref().context("engine not initialised")?;
                engine.index_fts_batch(indexed, FTS_BATCH_SIZE)?;
            }
            indexed = (indexed + FTS_BATCH_SIZE).min(total_rows);

            let progress = if total_rows > 0 {
                (indexed as f64 / total_rows as f64).min(1.0)
            } else {
                1.0
            };
            self.set_status(FileStatus::Loading {
                phase: "indexing".into(),
                progress,
                loaded_count: indexed as u64,
            });
            log::info!(
                "[indexing] progress={:.1}% indexed={}/{}",
                progress * 100.0,
                indexed,
                total_rows,
            );
            thread::yield_now();
        }

        Ok(start.elapsed())
    }

    // -- Helpers --------------------------------------------------------------

    fn report_reading_progress(
        &self,
        bytes_read: u64,
        total_bytes: u64,
        inserted_lines: usize,
    ) {
        let progress = if total_bytes > 0 {
            (bytes_read as f64 / total_bytes as f64).min(1.0)
        } else {
            0.0
        };
        self.set_status(FileStatus::Loading {
            phase: "reading".into(),
            progress,
            loaded_count: inserted_lines as u64,
        });
    }

    fn build_row(
        config: &Config,
        json_value: &Value,
        line: &str,
        line_no: usize,
    ) -> HashMap<String, String> {
        config
            .logs
            .iter()
            .map(|(col, path)| {
                (
                    col.clone(),
                    libparser::parser::extract_field(json_value, path, line, line_no),
                )
            })
            .collect()
    }

    /// If the file exceeds `max_bytes`, seek to `file_size - max_bytes` and
    /// discard the first partial line.
    fn maybe_seek_tail(
        file: &mut File,
        file_size: u64,
        max_bytes: Option<u64>,
    ) -> Result<bool> {
        match max_bytes {
            Some(max) if file_size > max => {
                file.seek(SeekFrom::Start(file_size - max))?;
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

    // -- Query delegation ---------------------------------------------------

    fn with_engine<T, F>(&self, default: T, f: F) -> Result<T>
    where
        F: FnOnce(&Engine) -> Result<T>,
    {
        let guard = self.engine.lock();
        match guard.as_ref() {
            Some(engine) => f(engine),
            None => Ok(default),
        }
    }
}

// ---------------------------------------------------------------------------
// Worker — thin facade that holds a swappable Arc<WorkerInstance>.
// ---------------------------------------------------------------------------

/// Global coordinator.  `open_file` creates a fresh `WorkerInstance`,
/// cancels the old one, and installs the new one as current.  All query
/// methods delegate to whichever instance is current.
pub struct Worker {
    current: Mutex<Arc<WorkerInstance>>,
}

impl Worker {
    fn new() -> Self {
        Self {
            current: Mutex::new(WorkerInstance::new()),
        }
    }

    /// Get a strong reference to the current instance.
    fn current(&self) -> Arc<WorkerInstance> {
        Arc::clone(&self.current.lock())
    }

    // -- Public API ---------------------------------------------------------

    pub fn get_status(&self) -> FileStatus {
        self.current().get_status()
    }

    pub fn open_file(&self, path: String, max_file_size: Option<u64>) {
        let new_inst = WorkerInstance::new();
        new_inst.set_status(FileStatus::Loading {
            phase: "reading".into(),
            progress: 0.0,
            loaded_count: 0,
        });

        // Swap in the new instance, cancel the old one.
        let old = {
            let mut cur = self.current.lock();
            std::mem::replace(&mut *cur, Arc::clone(&new_inst))
        };
        old.cancel();

        new_inst.start_load(path, max_file_size);
    }

    pub fn query_logs(
        &self,
        filter_sql: &str,
        fts_query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<(u32, QueryResult)> {
        self.current().with_engine(
            (0, QueryResult::empty()),
            |eng| eng.query_logs(filter_sql, fts_query, limit, offset),
        )
    }

    pub fn get_log_detail(&self, id: u32) -> Result<Option<String>> {
        self.current()
            .with_engine(None, |eng| eng.get_log_detail(id))
    }

    pub fn get_field_values(
        &self,
        field: &str,
        search: &str,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<String>> {
        self.current()
            .with_engine(vec![], |eng| eng.get_field_values(field, search, limit, offset))
    }
}

// ---------------------------------------------------------------------------
// Global singleton — accessed by the FRB API layer.
// ---------------------------------------------------------------------------

static WORKER: Lazy<Worker> = Lazy::new(Worker::new);

pub fn worker() -> &'static Worker {
    &WORKER
}

