use anyhow::Result;
use rusqlite::Connection;
use crate::config::Config;
use std::collections::HashMap;

pub struct Db {
    pub conn: Connection,
    pub columns: Vec<String>,
}

impl Db {
    pub fn new(config: &Config) -> Result<Self> {
        let conn = Connection::open_in_memory()?;
        
        let mut columns: Vec<String> = config.index.keys().cloned().collect();
        columns.sort(); // Ensure deterministic order for column mapping
        
        if columns.is_empty() {
             anyhow::bail!("No columns defined in config");
        }

        let schema = columns.iter()
            .map(|c| format!("{} TEXT", c))
            .collect::<Vec<_>>()
            .join(", ");
            
        // Add 'line_number' to track the original file line
        let create_sql = format!("CREATE TABLE logs (line_number INTEGER, {})", schema);
        conn.execute(&create_sql, [])?;
        
        Ok(Db { conn, columns })
    }

    pub fn insert_batch(&mut self, rows: &[(usize, HashMap<String, String>)]) -> Result<()> {
        let tx = self.conn.transaction()?;
        {
            let placeholders = vec!["?"; self.columns.len()].join(",");
            // Insert line_number as the first column
            let sql = format!("INSERT INTO logs (line_number, {}) VALUES (?, {})", self.columns.join(","), placeholders);
            let mut stmt = tx.prepare(&sql)?;

            for (line_num, row) in rows {
                let mut values: Vec<rusqlite::types::Value> = Vec::new();
                values.push((*line_num as i64).into()); // Add line_number

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
