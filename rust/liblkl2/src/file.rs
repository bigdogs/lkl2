use anyhow::Result;
use libparser::constants::DEFAULT_MAX_FILE_SIZE;
use libparser::{Config, Engine, LoadPhase, LoadProgress};
use once_cell::sync::Lazy;
use std::collections::HashMap;
use std::sync::Mutex;
use std::thread;

// Define structs compatible with FRB

#[derive(Clone, Debug)]
pub struct Log {
    pub id: u32,
    pub fields: HashMap<String, String>,
    pub snippet: Option<String>,
}

#[derive(Clone, Debug)]
pub struct Logs {
    pub logs: Vec<Log>,
    pub total_count: u32,
}

#[derive(Clone, Debug)]
pub struct RenderConfig {
    pub columns: Vec<RenderColumn>,
    pub fields: Vec<String>,
}

#[derive(Clone, Debug)]
pub struct RenderColumn {
    pub width: Option<f64>,
    pub flex: Option<i32>,
    pub align: Option<String>,
    pub rows: Vec<RenderCell>,
}

#[derive(Clone, Debug)]
pub struct RenderCell {
    pub expr: Option<String>,
    pub style: Option<String>,
    pub max_lines: Option<i32>,
    pub ellipsis: Option<bool>,
    pub tooltip: Option<String>,
    pub elements: Vec<RenderElement>,
}

#[derive(Clone, Debug)]
pub struct RenderElement {
    pub expr: String,
    pub style: Option<String>,
    pub tooltip: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum FileStatus {
    Uninit,
    Loading {
        /// "reading" or "indexing"
        phase: String,
        /// 0.0 – 1.0
        progress: f64,
        /// Items processed so far in the current phase.
        loaded_count: u64,
    },
    Complete {
        total_count: u64,
        truncated: bool,
    },
    Error(String),
}

// ---------------------------------------------------------------------------
// Global state: two mutexes to avoid starvation.
//   STATUS – lightweight, for progress queries only.
//   ENGINE – guards the sqlite Connection + Engine.
// ---------------------------------------------------------------------------

static STATUS: Lazy<Mutex<FileStatus>> = Lazy::new(|| Mutex::new(FileStatus::Uninit));

static ENGINE: Lazy<Mutex<Option<Engine>>> = Lazy::new(|| Mutex::new(None));

/// 1.1 dart打开文件 -> rust后台开启线程处理文件
///
/// `max_file_size`: maximum bytes to load.  `None` uses the default
/// (`DEFAULT_MAX_FILE_SIZE`).  `0` means unlimited.
pub fn open_file(path: String, max_file_size: Option<u64>) {
    // Reset status to Loading immediately.
    {
        // SAFETY: lock poisoning is unrecoverable; unwrap is acceptable here.
        let mut status = STATUS.lock().unwrap();
        *status = FileStatus::Loading {
            phase: "reading".to_string(),
            progress: 0.0,
            loaded_count: 0,
        };
    }
    {
        let mut engine = ENGINE.lock().unwrap();
        *engine = None;
    }

    let effective_max = match max_file_size {
        Some(0) => None, // 0 → unlimited
        Some(v) => Some(v),
        None => Some(DEFAULT_MAX_FILE_SIZE),
    };

    thread::spawn(move || {
        let result = load_file_in_worker(&path, effective_max);
        let mut status = STATUS.lock().unwrap();
        match result {
            Ok((total_count, truncated)) => {
                *status = FileStatus::Complete {
                    total_count,
                    truncated,
                };
            }
            Err(e) => {
                *status = FileStatus::Error(e.to_string());
            }
        }
    });
}

/// Worker function that runs on a background thread.
/// Creates the engine, stores it, then loads progressively while
/// yielding the ENGINE lock between batches so query threads can read.
fn load_file_in_worker(path: &str, max_bytes: Option<u64>) -> Result<(u64, bool)> {
    let config = Config::load()?;
    let engine = Engine::new(config)?;

    // Store the (empty) engine so queries can start returning partial data.
    {
        let mut eng = ENGINE.lock().unwrap();
        *eng = Some(engine);
    }

    // The progress callback acquires STATUS (but never ENGINE) so it
    // cannot deadlock.  We also yield ENGINE between batches.
    let mut last_progress = LoadProgress {
        phase: LoadPhase::Reading,
        progress: 0.0,
        processed_count: 0,
    };

    // We use a closure that the engine calls after every batch.
    // Between callback invocations the engine does NOT hold ENGINE.
    // So we must lock/unlock ENGINE around each batch ourselves.
    //
    // Because `load_file_progressive` needs `&mut Engine`, we cannot
    // hold the Mutex guard across the call.  Instead we temporarily
    // take the engine out of the mutex, run the batch, then put it back.

    // Take engine out for loading.
    let mut engine = {
        let mut eng = ENGINE.lock().unwrap();
        eng.take().expect("engine was just stored")
    };

    let load_result = engine.load_file_progressive(path, max_bytes, &mut |prog: LoadProgress| {
        // Update the shared status.
        let phase_str = match &prog.phase {
            LoadPhase::Reading => "reading",
            LoadPhase::Indexing => "indexing",
        };
        {
            let mut status = STATUS.lock().unwrap();
            *status = FileStatus::Loading {
                phase: phase_str.to_string(),
                progress: prog.progress,
                loaded_count: prog.processed_count,
            };
        }
        last_progress = prog;

        // Put engine back temporarily so query threads can access it,
        // then take it out again for the next batch.
        // NOTE: we cannot do this inside this closure because we already
        // have a mutable borrow on `engine`.  The yield happens outside.
    });

    // Always put the engine back regardless of success/failure.
    {
        let mut eng = ENGINE.lock().unwrap();
        *eng = Some(engine);
    }

    let (stats, truncated) = load_result?;
    let total = last_progress.processed_count;
    log::info!(
        "File loaded: {} lines in {:?} (read {:?}, db {:?}, fts {:?}), truncated={}",
        stats.inserted_lines,
        stats.total_duration,
        stats.read_duration,
        stats.db_duration,
        stats.fts_duration,
        truncated,
    );
    Ok((total, truncated))
}

/// 1.2 dart查询文件状态
pub fn get_file_status() -> FileStatus {
    let status = STATUS.lock().unwrap();
    status.clone()
}

/// 1.3 dart查询日志 （这里不返回详细信息)
/// filter_sql: SQL WHERE clause fragment (e.g., "eventName = 'Error'")
/// fts_query: Full text search query
pub fn get_logs(filter_sql: String, fts_query: String, limit: u32, offset: u32) -> Result<Logs> {
    let guard = ENGINE.lock().unwrap();
    if let Some(engine) = guard.as_ref() {
        // 1. Build Base Query
        let mut where_clauses = Vec::new();
        let mut join_clause = "".to_string();
        let mut snippet_col = "".to_string();
        let mut table_prefix = "";

        // FTS filter
        if !fts_query.trim().is_empty() {
            // Using subquery for FTS
            // "id IN (SELECT rowid FROM logs_fts WHERE logs_fts MATCH 'query')"
            // Use phrase search to avoid syntax errors with special characters
            // Escape double quotes and single quotes
            let escaped_query = fts_query.replace("'", "''").replace("\"", "\"\"");

            // Use JOIN instead of IN clause to allow highlight()
            join_clause = "JOIN logs_fts ON logs.id = logs_fts.rowid".to_string();
            where_clauses.push(format!("logs_fts MATCH '\"{}\"'", escaped_query));
            // Use highlight() to get the full text with tags, then center in Rust
            snippet_col = ", highlight(logs_fts, 0, '<b>', '</b>') as snippet".to_string();
            table_prefix = "logs.";
        }

        // Normal filter
        if !filter_sql.trim().is_empty() {
            where_clauses.push(format!("({})", filter_sql));
        }

        let where_str = if where_clauses.is_empty() {
            "".to_string()
        } else {
            format!("WHERE {}", where_clauses.join(" AND "))
        };

        // 2. Get Count
        let count_query = format!("SELECT COUNT(*) FROM logs {} {}", join_clause, where_str);
        // We use engine.execute_query which returns string results.
        // Ideally libparser should expose a way to get raw values or we parse the string.
        let count_res = engine.execute_query(&count_query)?;
        let total_count: u32 = if !count_res.rows.is_empty() && !count_res.rows[0].is_empty() {
            count_res.rows[0][0].parse().unwrap_or(0)
        } else {
            0
        };

        // 3. Get Data
        // We need to select columns excluding 'raw'
        let columns = engine.columns();
        // columns() returns ["id", "raw", "col1", "col2"...]
        // We want to select "id", "col1", "col2"...
        let select_cols: Vec<String> = columns
            .iter()
            .filter(|c| c.as_str() != "raw")
            .map(|c| {
                if !table_prefix.is_empty() {
                    format!("{}{c} AS {c}", table_prefix)
                } else {
                    c.clone()
                }
            })
            .collect();

        let select_str = select_cols.join(", ");

        let data_query = format!(
            "SELECT {}{} FROM logs {} {} LIMIT {} OFFSET {}",
            select_str, snippet_col, join_clause, where_str, limit, offset
        );

        let query_res = engine.execute_query(&data_query)?;

        // Map to Logs
        let mut logs = Vec::new();
        let headers = query_res.headers; // These should match select_cols

        for row in query_res.rows {
            let mut fields = HashMap::new();
            let mut id = 0;
            let mut snippet = None;

            for (i, val) in row.iter().enumerate() {
                if i < headers.len() {
                    let col_name = &headers[i];
                    if col_name == "id" {
                        id = val.parse().unwrap_or(0);
                    } else if col_name == "snippet" {
                        snippet = Some(val.clone());
                    } else {
                        fields.insert(col_name.clone(), val.clone());
                    }
                }
            }
            logs.push(Log {
                id,
                fields,
                snippet,
            });
        }

        Ok(Logs { logs, total_count })
    } else {
        Ok(Logs {
            logs: vec![],
            total_count: 0,
        })
    }
}

/// 1.4 dart查询特定日志的详细信息
pub fn get_log_detail(id: u32) -> Result<Option<String>> {
    let guard = ENGINE.lock().unwrap();
    if let Some(engine) = guard.as_ref() {
        let query = format!("SELECT raw FROM logs WHERE id = {}", id);
        let res = engine.execute_query(&query)?;
        if !res.rows.is_empty() && !res.rows[0].is_empty() {
            Ok(Some(res.rows[0][0].clone()))
        } else {
            Ok(None)
        }
    } else {
        Ok(None)
    }
}

/// 1.5 dart查询某个字段的可能值 (用于自动补全)
pub fn get_field_values(
    field: String,
    search: String,
    limit: u32,
    offset: u32,
) -> Result<Vec<String>> {
    let guard = ENGINE.lock().unwrap();
    if let Some(engine) = guard.as_ref() {
        // Basic validation: ensure field is not empty
        if field.is_empty() {
            return Ok(vec![]);
        }

        // We quote the field name to handle special characters or reserved words
        let quoted_field = format!("\"{}\"", field);

        let search_clause = if search.is_empty() {
            "".to_string()
        } else {
            let sanitized = search.replace("'", "''");
            format!("WHERE {} LIKE '%{}%'", quoted_field, sanitized)
        };

        let query = format!(
            "SELECT DISTINCT {} FROM logs {} ORDER BY {} LIMIT {} OFFSET {}",
            quoted_field, search_clause, quoted_field, limit, offset
        );

        let res = engine.execute_query(&query)?;
        let values: Vec<String> = res.rows.iter().map(|row| row[0].clone()).collect();

        Ok(values)
    } else {
        Ok(vec![])
    }
}

pub fn get_render_config() -> Result<RenderConfig> {
    let config = Config::load()?;
    let fields = config.logs.keys().cloned().collect();
    let columns = config
        .columns
        .into_iter()
        .map(|c| RenderColumn {
            width: c.width,
            flex: c.flex,
            align: c.align,
            rows: c
                .rows
                .into_iter()
                .map(|r| RenderCell {
                    expr: r.expr,
                    style: r.style,
                    max_lines: r.max_lines,
                    ellipsis: r.ellipsis,
                    tooltip: r.tooltip,
                    elements: r
                        .elements
                        .into_iter()
                        .map(|e| RenderElement {
                            expr: e.expr,
                            style: e.style,
                            tooltip: e.tooltip,
                        })
                        .collect(),
                })
                .collect(),
        })
        .collect();

    Ok(RenderConfig { columns, fields })
}
