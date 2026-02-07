use anyhow::Result;
use libparser::{Config, Engine};
use once_cell::sync::Lazy;
use std::collections::HashMap;
use std::sync::Mutex;
use std::thread;

// Define structs compatible with FRB

#[derive(Clone, Debug)]
pub struct Log {
    pub id: u32,
    pub fields: HashMap<String, String>,
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
    pub elements: Vec<RenderElement>,
}

#[derive(Clone, Debug)]
pub struct RenderElement {
    pub expr: String,
    pub style: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum FileStatus {
    Uninit,
    Pending,
    Complete,
    Error(String),
}

// Global State
struct AppState {
    engine: Option<Engine>,
    status: FileStatus,
}

static STATE: Lazy<Mutex<AppState>> = Lazy::new(|| {
    Mutex::new(AppState {
        engine: None,
        status: FileStatus::Uninit,
    })
});

/// 1.1 dart打开文件 -> rust后台开启线程处理文件
pub fn open_file(path: String) {
    // Set status to Pending
    {
        let mut state = STATE.lock().unwrap();
        state.status = FileStatus::Pending;
        state.engine = None;
    }

    thread::spawn(move || {
        let res = (|| -> Result<Engine> {
            let config = Config::load()?;
            let mut engine = Engine::new(config)?;
            engine.load_file(&path)?;
            Ok(engine)
        })();

        let mut state = STATE.lock().unwrap();
        match res {
            Ok(engine) => {
                state.engine = Some(engine);
                state.status = FileStatus::Complete;
            }
            Err(e) => {
                state.status = FileStatus::Error(e.to_string());
            }
        }
    });
}

/// 1.2 dart查询文件状态
pub fn get_file_status() -> FileStatus {
    let state = STATE.lock().unwrap();
    state.status.clone()
}

/// 1.3 dart查询日志 （这里不返回详细信息)
/// filter_sql: SQL WHERE clause fragment (e.g., "eventName = 'Error'")
/// fts_query: Full text search query
pub fn get_logs(
    filter_sql: String,
    fts_query: String,
    limit: u32,
    offset: u32,
) -> Result<Logs> {
    let state = STATE.lock().unwrap();
    if let Some(engine) = &state.engine {
        // 1. Build Base Query
        let mut where_clauses = Vec::new();
        
        // FTS filter
        if !fts_query.trim().is_empty() {
            // Using subquery for FTS
            // "id IN (SELECT rowid FROM logs_fts WHERE logs_fts MATCH 'query')"
            // Use phrase search to avoid syntax errors with special characters
            // Escape double quotes and single quotes
            let escaped_query = fts_query.replace("'", "''").replace("\"", "\"\"");
            where_clauses.push(format!("id IN (SELECT rowid FROM logs_fts WHERE logs_fts MATCH '\"{}\"')", escaped_query));
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
        let count_query = format!("SELECT COUNT(*) FROM logs {}", where_str);
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
        let select_cols: Vec<String> = columns.iter()
            .filter(|c| c.as_str() != "raw")
            .cloned()
            .collect();
        
        let select_str = select_cols.join(", ");
        
        let data_query = format!(
            "SELECT {} FROM logs {} LIMIT {} OFFSET {}",
            select_str, where_str, limit, offset
        );
        
        let query_res = engine.execute_query(&data_query)?;
        
        // Map to Logs
        let mut logs = Vec::new();
        let headers = query_res.headers; // These should match select_cols
        
        for row in query_res.rows {
            let mut fields = HashMap::new();
            let mut id = 0;
            
            for (i, val) in row.iter().enumerate() {
                if i < headers.len() {
                    let col_name = &headers[i];
                    if col_name == "id" {
                        id = val.parse().unwrap_or(0);
                    } else {
                        fields.insert(col_name.clone(), val.clone());
                    }
                }
            }
            logs.push(Log { id, fields });
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
    let state = STATE.lock().unwrap();
    if let Some(engine) = &state.engine {
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
    let state = STATE.lock().unwrap();
    if let Some(engine) = &state.engine {
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
        let values: Vec<String> = res.rows.iter()
            .map(|row| row[0].clone())
            .collect();
        
        Ok(values)
    } else {
        Ok(vec![])
    }
}

pub fn get_render_config() -> Result<RenderConfig> {
    let config = Config::load()?;
    let fields = config.logs.keys().cloned().collect();
    let columns = config.columns.into_iter().map(|c| RenderColumn {
        width: c.width,
        flex: c.flex,
        align: c.align,
        rows: c.rows.into_iter().map(|r| RenderCell {
            expr: r.expr,
            style: r.style,
            max_lines: r.max_lines,
            ellipsis: r.ellipsis,
            elements: r.elements.into_iter().map(|e| RenderElement {
                expr: e.expr,
                style: e.style,
            }).collect(),
        }).collect(),
    }).collect();

    Ok(RenderConfig { columns, fields })
}
