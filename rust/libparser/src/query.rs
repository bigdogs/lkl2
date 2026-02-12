use anyhow::Result;
use std::time::Instant;

use crate::engine::Engine;
use crate::QueryResult;

// ---------------------------------------------------------------------------
// Public query API
// ---------------------------------------------------------------------------
impl Engine {
    /// Query logs with optional SQL filter and FTS search.
    /// Returns (total_matching_count, page_of_results).
    pub fn query_logs(
        &self,
        filter_sql: &str,
        fts_query: &str,
        limit: u32,
        offset: u32,
    ) -> Result<(u32, QueryResult)> {
        let ctx = QueryContext::build(filter_sql, fts_query);
        let total_count = self.count_matching(&ctx)?;
        let result = self.select_page(&ctx, limit, offset)?;
        Ok((total_count, result))
    }

    /// Get distinct values for a column (for autocomplete).
    pub fn get_field_values(
        &self,
        field: &str,
        search: &str,
        limit: u32,
        offset: u32,
    ) -> Result<Vec<String>> {
        if field.is_empty() {
            return Ok(vec![]);
        }

        let quoted = format!("\"{}\"", field);
        let filter = if search.is_empty() {
            String::new()
        } else {
            let sanitized = search.replace('\'', "''");
            format!("WHERE {} LIKE '%{}%'", quoted, sanitized)
        };

        let sql = format!(
            "SELECT DISTINCT {} FROM logs {} ORDER BY {} LIMIT {} OFFSET {}",
            quoted, filter, quoted, limit, offset,
        );
        let res = self.execute_query(&sql)?;
        Ok(res.rows.iter().map(|r| r[0].clone()).collect())
    }

    /// Get the raw JSON text for a single log entry.
    pub fn get_log_detail(&self, id: u32) -> Result<Option<String>> {
        let sql = format!("SELECT raw FROM logs WHERE id = {}", id);
        let res = self.execute_query(&sql)?;
        Ok(res.rows.first().and_then(|r| r.first().cloned()))
    }

    /// Execute an arbitrary SQL query against the logs database.
    pub fn execute_query(&self, sql: &str) -> Result<QueryResult> {
        let start = Instant::now();
        let mut stmt = self.db.conn.prepare(sql)?;
        let headers: Vec<String> = stmt.column_names().iter().map(|s| s.to_string()).collect();
        let mut rows_iter = stmt.query([])?;
        let mut rows = Vec::new();

        while let Some(row) = rows_iter.next()? {
            let values: Vec<String> = (0..headers.len())
                .map(|i| format_sqlite_value(row.get_ref(i).unwrap_or(rusqlite::types::ValueRef::Null)))
                .collect();
            rows.push(values);
        }

        Ok(QueryResult {
            headers,
            rows,
            duration: start.elapsed(),
        })
    }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Pre-computed SQL fragments for a query_logs call.
struct QueryContext {
    join_clause: String,
    where_clause: String,
    snippet_col: String,
    table_prefix: &'static str,
}

impl QueryContext {
    fn build(filter_sql: &str, fts_query: &str) -> Self {
        let mut where_parts = Vec::new();
        let mut join_clause = String::new();
        let mut snippet_col = String::new();
        let mut table_prefix = "";

        if !fts_query.trim().is_empty() {
            let escaped = fts_query.replace('\'', "''").replace('"', "\"\"");
            join_clause = "JOIN logs_fts ON logs.id = logs_fts.rowid".to_string();
            where_parts.push(format!("logs_fts MATCH '\"{}\"'", escaped));
            snippet_col =
                ", highlight(logs_fts, 0, '<b>', '</b>') as snippet".to_string();
            table_prefix = "logs.";
        }

        if !filter_sql.trim().is_empty() {
            where_parts.push(format!("({})", filter_sql));
        }

        let where_clause = if where_parts.is_empty() {
            String::new()
        } else {
            format!("WHERE {}", where_parts.join(" AND "))
        };

        Self {
            join_clause,
            where_clause,
            snippet_col,
            table_prefix,
        }
    }
}

impl Engine {
    fn count_matching(&self, ctx: &QueryContext) -> Result<u32> {
        let sql = format!(
            "SELECT COUNT(*) FROM logs {} {}",
            ctx.join_clause, ctx.where_clause,
        );
        let res = self.execute_query(&sql)?;
        let count = res
            .rows
            .first()
            .and_then(|r| r.first())
            .and_then(|v| v.parse().ok())
            .unwrap_or(0);
        Ok(count)
    }

    fn select_page(
        &self,
        ctx: &QueryContext,
        limit: u32,
        offset: u32,
    ) -> Result<QueryResult> {
        let select_cols: Vec<String> = self
            .columns()
            .into_iter()
            .filter(|c| c != "raw")
            .map(|c| {
                if ctx.table_prefix.is_empty() {
                    c
                } else {
                    format!("{}{c} AS {c}", ctx.table_prefix)
                }
            })
            .collect();

        let sql = format!(
            "SELECT {}{} FROM logs {} {} LIMIT {} OFFSET {}",
            select_cols.join(", "),
            ctx.snippet_col,
            ctx.join_clause,
            ctx.where_clause,
            limit,
            offset,
        );
        self.execute_query(&sql)
    }
}

impl QueryResult {
    pub fn empty() -> Self {
        Self {
            headers: vec![],
            rows: vec![],
            duration: std::time::Duration::ZERO,
        }
    }
}

fn format_sqlite_value(value: rusqlite::types::ValueRef<'_>) -> String {
    match value {
        rusqlite::types::ValueRef::Null => "NULL".to_string(),
        rusqlite::types::ValueRef::Integer(i) => i.to_string(),
        rusqlite::types::ValueRef::Real(f) => f.to_string(),
        rusqlite::types::ValueRef::Text(t) => String::from_utf8_lossy(t).to_string(),
        rusqlite::types::ValueRef::Blob(_) => "[BLOB]".to_string(),
    }
}
