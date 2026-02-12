use anyhow::Result;
use libparser::config::{ColumnConfig, ElementConfig, RowConfig};
use libparser::Config;
use log::info;
use std::collections::HashMap;
use std::fs::File;
use std::time::Instant;

use crate::worker;

// Re-export FileStatus so FRB generated code can access it as crate::file::FileStatus.
pub use crate::worker::FileStatus;

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

// Re-export FileStatus so FRB can see it from this module.
pub use crate::worker::FileStatus as FrbFileStatus;

/// Global init. `log_dir` is a writable directory for the log file.
pub fn init(log_dir: String) {
    let log_path = std::path::Path::new(&log_dir).join("lkl2.log");
    let Ok(log_file) = File::create(&log_path) else {
        // If the log file can't be created, fall back to stderr logging.
        env_logger::Builder::from_default_env()
            .filter_level(log::LevelFilter::Info)
            .format_timestamp_millis()
            .try_init()
            .ok();
        return;
    };
    env_logger::Builder::from_default_env()
        .filter_level(log::LevelFilter::Info)
        .format_timestamp_millis()
        .target(env_logger::Target::Pipe(Box::new(log_file)))
        .try_init()
        .ok();
    info!("Logging to {}", log_path.display());
}

// ---------------------------------------------------------------------------
// Public FRB API
// ---------------------------------------------------------------------------

/// Open a log file.  Loading happens on a background thread.
pub fn open_file(path: String, max_file_size: Option<u64>) {
    let start = Instant::now();
    worker::worker().open_file(path.clone(), max_file_size);
    info!(
        "open_file(path={:?}, max_file_size={:?}) in {:?}",
        path,
        max_file_size,
        start.elapsed()
    );
}

/// Poll the current loading status.
pub fn get_file_status() -> FileStatus {
    let status = worker::worker().get_status();
    info!("get_file_status() -> {:?} ", status);
    status
}

/// Query logs with optional SQL filter / FTS search.
pub fn get_logs(filter_sql: String, fts_query: String, limit: u32, offset: u32) -> Result<Logs> {
    let start = Instant::now();
    let (total_count, result) =
        worker::worker().query_logs(&filter_sql, &fts_query, limit, offset)?;
    let logs = map_query_rows(&result.headers, result.rows);
    info!("get_logs(filter_sql={:?}, fts_query={:?}, limit={}, offset={}) -> {} rows, total_count={} in {:?}", filter_sql, fts_query, limit, offset, logs.len(), total_count, start.elapsed());
    Ok(Logs { logs, total_count })
}

/// Get the raw JSON text for one log entry.
pub fn get_log_detail(id: u32) -> Result<Option<String>> {
    let start = Instant::now();
    let result = worker::worker().get_log_detail(id)?;
    info!(
        "get_log_detail(id={}) -> found={} in {:?}",
        id,
        result.is_some(),
        start.elapsed()
    );
    Ok(result)
}

/// Get distinct values of a field (for autocomplete).
pub fn get_field_values(
    field: String,
    search: String,
    limit: u32,
    offset: u32,
) -> Result<Vec<String>> {
    let start = Instant::now();
    let result = worker::worker().get_field_values(&field, &search, limit, offset)?;
    info!(
        "get_field_values(field={:?}, search={:?}, limit={}, offset={}) -> {} items in {:?}",
        field,
        search,
        limit,
        offset,
        result.len(),
        start.elapsed()
    );
    Ok(result)
}

/// Load the render configuration from the embedded config file.
pub fn get_render_config() -> Result<RenderConfig> {
    let start = Instant::now();
    let config = Config::load()?;
    let render_config = build_render_config(config);
    info!(
        "get_render_config() -> {} columns, {} fields in {:?}",
        render_config.columns.len(),
        render_config.fields.len(),
        start.elapsed()
    );
    Ok(render_config)
}

// ---------------------------------------------------------------------------
// Mapping helpers
// ---------------------------------------------------------------------------

fn map_query_rows(headers: &[String], rows: Vec<Vec<String>>) -> Vec<Log> {
    rows.into_iter()
        .map(|row| {
            let mut fields = HashMap::new();
            let mut id: u32 = 0;
            let mut snippet = None;

            for (i, val) in row.into_iter().enumerate() {
                if i >= headers.len() {
                    continue;
                }
                match headers[i].as_str() {
                    "id" => id = val.parse().unwrap_or(0),
                    "snippet" => snippet = Some(val),
                    col => {
                        fields.insert(col.to_string(), val);
                    }
                }
            }
            Log {
                id,
                fields,
                snippet,
            }
        })
        .collect()
}

fn build_render_config(config: Config) -> RenderConfig {
    RenderConfig {
        fields: config.logs.keys().cloned().collect(),
        columns: config.columns.into_iter().map(Into::into).collect(),
    }
}

impl From<ColumnConfig> for RenderColumn {
    fn from(c: ColumnConfig) -> Self {
        Self {
            width: c.width,
            flex: c.flex,
            align: c.align,
            rows: c.rows.into_iter().map(Into::into).collect(),
        }
    }
}

impl From<RowConfig> for RenderCell {
    fn from(r: RowConfig) -> Self {
        Self {
            expr: r.expr,
            style: r.style,
            max_lines: r.max_lines,
            ellipsis: r.ellipsis,
            tooltip: r.tooltip,
            elements: r.elements.into_iter().map(Into::into).collect(),
        }
    }
}

impl From<ElementConfig> for RenderElement {
    fn from(e: ElementConfig) -> Self {
        Self {
            expr: e.expr,
            style: e.style,
            tooltip: e.tooltip,
        }
    }
}
