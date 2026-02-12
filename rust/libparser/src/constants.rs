/// Number of rows per insert batch during file loading.
pub const BATCH_SIZE: usize = 1000;

/// Number of rows per FTS5 incremental indexing batch.
pub const FTS_BATCH_SIZE: i64 = 1000;
