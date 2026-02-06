use anyhow::Result;
use serde::Deserialize;
use std::collections::HashMap;

// #[derive(Embed)]
// #[folder = "rules"]
// struct Asset;

const RULES: &str = include_str!("../rules/lkl2.toml");

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub logs: HashMap<String, String>,
    #[serde(rename = "col", default)]
    pub columns: Vec<ColumnConfig>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ColumnConfig {
    pub width: Option<f64>,
    pub flex: Option<i32>,
    #[serde(rename = "row", default)]
    pub rows: Vec<RowConfig>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct RowConfig {
    pub expr: String,
    pub style: Option<String>,
    pub max_lines: Option<i32>,
    pub ellipsis: Option<bool>,
}

impl Config {
    pub fn load() -> Result<Self> {
        // let file = Asset::get("lkl2.toml").ok_or_else(|| {
        //     anyhow::anyhow!(
        //         "Failed to find embedded lkl2.toml. Available: {:?}",
        //         Asset::iter().collect::<Vec<_>>()
        //     )
        // })?;
        // let content = std::str::from_utf8(file.data.as_ref())?;
        let config: Config = toml::from_str(RULES)?;
        Ok(config)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_load_config() {
        let config = Config::load();
        assert!(config.is_ok(), "Config load failed: {:?}", config.err());
        let config = config.unwrap();
        println!("Loaded config: {:?}", config);
        assert_eq!(config.columns.len(), 4, "Expected 4 columns, got {}", config.columns.len());
        
        // Check rows of last column
        let last_col = config.columns.last().unwrap();
        assert_eq!(last_col.rows.len(), 2, "Expected 2 rows in last column");
    }
}
