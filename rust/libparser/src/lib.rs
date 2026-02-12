use std::time::Duration;

pub mod config;
pub mod constants;
pub mod db;
pub mod engine;
pub mod loader;
pub mod parser;
pub mod query;

pub use config::Config;
pub use engine::Engine;

// ---------------------------------------------------------------------------
// Shared types used across modules
// ---------------------------------------------------------------------------

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

