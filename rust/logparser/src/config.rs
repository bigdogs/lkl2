use rust_embed::RustEmbed;
use serde::Deserialize;
use std::collections::HashMap;
use anyhow::Result;

#[derive(RustEmbed)]
#[folder = "."]
#[include = "lkl2.toml"]
struct Asset;

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub index: HashMap<String, String>,
}

impl Config {
    pub fn load() -> Result<Self> {
        let file = Asset::get("lkl2.toml")
            .ok_or_else(|| anyhow::anyhow!("Failed to find embedded lkl2.toml"))?;
        let content = std::str::from_utf8(file.data.as_ref())?;
        let config: Config = toml::from_str(content)?;
        Ok(config)
    }
}
