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
