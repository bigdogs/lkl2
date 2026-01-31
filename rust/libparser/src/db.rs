use crate::config::Config;
use anyhow::Result;
use rusqlite::Connection;
use std::collections::HashMap;

pub struct Db {
    pub conn: Connection,
    pub columns: Vec<String>,
}

impl Db {
    pub fn new(config: &Config) -> Result<Self> {
        let conn = Connection::open_in_memory()?;

        let mut columns: Vec<String> = config.logs.keys().cloned().collect();
        columns.sort();

        for col in &columns {
            let lower = col.to_lowercase();
            if lower == "id" || lower == "raw" {
                anyhow::bail!("Column '{}' is reserved and cannot be redefined", col);
            }
        }

        let mut schema_parts = vec!["id INTEGER PRIMARY KEY".to_string(), "raw TEXT".to_string()];
        schema_parts.extend(columns.iter().map(|c| format!("{} TEXT", c)));
        let create_sql = format!("CREATE TABLE logs ({})", schema_parts.join(", "));
        conn.execute(&create_sql, [])?;

        conn.execute(
            "CREATE VIRTUAL TABLE logs_fts USING fts5(raw, content='logs', content_rowid='id', tokenize='trigram', detail='none')",
            [],
        )?;

        Ok(Db { conn, columns })
    }

    pub fn rebuild_fts(&self) -> Result<()> {
        self.conn
            .execute("INSERT INTO logs_fts(logs_fts) VALUES('rebuild')", [])?;
        Ok(())
    }

    pub fn insert_batch(&mut self, rows: &[(String, HashMap<String, String>)]) -> Result<()> {
        let tx = self.conn.transaction()?;
        {
            let mut insert_columns = Vec::with_capacity(self.columns.len() + 1);
            insert_columns.push("raw".to_string());
            insert_columns.extend(self.columns.iter().cloned());
            let placeholders = vec!["?"; insert_columns.len()].join(",");
            let sql = format!(
                "INSERT INTO logs ({}) VALUES ({})",
                insert_columns.join(","),
                placeholders
            );
            let mut stmt = tx.prepare(&sql)?;

            for (raw, row) in rows {
                let mut values: Vec<rusqlite::types::Value> =
                    Vec::with_capacity(insert_columns.len());
                values.push(raw.clone().into());

                for col in &self.columns {
                    let val = row.get(col).cloned().unwrap_or_default();
                    values.push(val.into());
                }
                stmt.execute(rusqlite::params_from_iter(values))?;
            }
        }
        tx.commit()?;
        Ok(())
    }
}
