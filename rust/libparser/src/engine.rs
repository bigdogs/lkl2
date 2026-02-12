use anyhow::{Context, Result};

use crate::config::Config;
use crate::db::Db;

pub struct Engine {
    pub(crate) config: Config,
    pub(crate) db: Db,
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

    /// Returns all column names: ["id", "raw", <user-defined columns...>].
    pub fn columns(&self) -> Vec<String> {
        let mut cols = Vec::with_capacity(self.db.columns.len() + 2);
        cols.push("id".to_string());
        cols.push("raw".to_string());
        cols.extend(self.db.columns.clone());
        cols
    }

    /// Borrow the config (read-only).
    pub fn config(&self) -> &Config {
        &self.config
    }

    /// Insert a batch of rows into the database.
    pub fn insert_batch(
        &mut self,
        rows: &[(String, std::collections::HashMap<String, String>)],
    ) -> Result<()> {
        self.db.insert_batch(rows)
    }

    /// Incrementally index a batch of rows into the FTS5 table.
    pub fn index_fts_batch(&self, from_id: i64, batch_size: i64) -> Result<()> {
        self.db.index_fts_batch(from_id, batch_size)
    }

    /// Returns the total number of rows in the `logs` table.
    pub fn get_row_count(&self) -> Result<i64> {
        self.db.get_row_count()
    }
}
