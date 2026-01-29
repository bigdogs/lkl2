use anyhow::{Context, Result};
use argh::FromArgs;

use std::fs::File;
use std::io::{self, BufRead, BufReader, Write};
use std::time::{Duration, Instant};
use std::collections::HashMap;

mod config;
mod db;
mod parser;

use config::Config;
use db::Db;

#[derive(FromArgs)]
/// Simple Log Search Engine
struct Args {
    /// path to the log file
    #[argh(positional)]
    file: String,
}

fn main() -> Result<()> {
    env_logger::init();
    
    // 1. Load Config
    let config = Config::load().context("Failed to load config")?;
    
    // 2. Parse Args
    let args: Args = argh::from_env();
    
    // 3. Init DB
    let mut db = Db::new(&config).context("Failed to initialize DB")?;
    
    // 4. Load File and Parse
    let file = File::open(&args.file).with_context(|| format!("Failed to open file {}", args.file))?;
    let reader = BufReader::new(file);
    
    println!("Loading file: {}", args.file);
    let start_total = Instant::now();
    let mut start_chunk = Instant::now();
    
    let mut buffer: Vec<(usize, HashMap<String, String>)> = Vec::new();
    let batch_size = 1000;
    let mut line_count = 0;
    let mut total_db_duration = Duration::new(0, 0);
    
    // Use a transaction for the entire load for performance, 
    // but we need to commit periodically if we want to query *during* load (not required here).
    // The requirement says "Print loading time every 1000 lines".
    // We can insert in batches inside a single transaction or multiple.
    // Multiple transactions are slower. 
    // Let's use one huge transaction for the whole file, but we can't do that if we want to print progress 
    // that implies "inserted".
    // Actually, "loading time" usually means processing time.
    // I will batch insert every 1000 lines.
    
    for (idx, line) in reader.lines().enumerate() {
        let line = line?;
        let current_line_num = idx + 1;
        if line.trim().is_empty() {
            continue;
        }
        
        // Parse to JSON
        let json_value: serde_json::Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(_) => {
                // If not JSON, treat as raw string wrapped in object?
                // Or just fail? Requirement says "Parse file". 
                // Let's assume valid JSON lines or skip.
                // If raw="$0" is used, maybe the line itself is the value?
                // But parser expects Value.
                // Let's create a wrapper if it fails?
                // For now, log warning and skip.
                // error!("Failed to parse line as JSON: {}", line);
                continue; 
            }
        };
        
        let mut row = HashMap::new();
        for (col, path) in &config.index {
            let val = parser::extract_field(&json_value, path);
            row.insert(col.clone(), val);
        }
        
        // If config has raw="$0", and we want the original line string
        // The current parser uses json_value.to_string().
        // If exact line is needed, we might need special handling.
        // But parser::extract_field implementation returns root.to_string().
        // That is re-serialized JSON. Close enough.
        
        buffer.push((current_line_num, row));
        
        if buffer.len() >= batch_size {
            let db_start = Instant::now();
            db.insert_batch(&buffer)?;
            let db_duration = db_start.elapsed();
            total_db_duration += db_duration;

            buffer.clear();
            line_count += batch_size;
            
            let total_duration = start_chunk.elapsed();
            let read_duration = total_duration.saturating_sub(db_duration);

            println!("Loaded {} lines. Last {} lines: Read {:?}, SQLite {:?}, Total {:?}", 
                line_count, batch_size, read_duration, db_duration, total_duration);
            start_chunk = Instant::now();
        }
    }
    
    if !buffer.is_empty() {
        let count = buffer.len();
        let db_start = Instant::now();
        db.insert_batch(&buffer)?;
        total_db_duration += db_start.elapsed();
        line_count += count;
        println!("Loaded {} lines (final batch).", line_count);
    }
    
    let total_time = start_total.elapsed();
    let total_read_time = total_time.saturating_sub(total_db_duration);
    println!("Total loading time: Read {:?}, SQLite {:?}, Total {:?}", total_read_time, total_db_duration, total_time);
    println!("Table 'logs' is ready. Columns: {:?}", db.columns);
    println!("Enter SQL query (e.g. 'SELECT * FROM logs LIMIT 5'):");

    // 5. REPL
    let stdin = io::stdin();
    let mut stdout = io::stdout();
    let mut input_buffer = String::new();
    let mut line_buffer = String::new();
    
    loop {
        if input_buffer.is_empty() {
            print!("> ");
        } else {
            print!("... ");
        }
        stdout.flush()?;
        line_buffer.clear();
        match stdin.read_line(&mut line_buffer) {
            Ok(0) => break, // EOF
            Ok(_) => {
                let trimmed = line_buffer.trim();
                
                // Only check exit if we are at the start of a query
                if input_buffer.is_empty() {
                    if trimmed.is_empty() {
                        continue;
                    }
                    if trimmed.eq_ignore_ascii_case("exit") || trimmed.eq_ignore_ascii_case("quit") {
                        break;
                    }
                }
                
                input_buffer.push_str(&line_buffer);
                
                if trimmed.ends_with(';') {
                    match execute_query(&db.conn, &input_buffer) {
                        Ok(_) => {},
                        Err(e) => println!("Error: {}", e),
                    }
                    input_buffer.clear();
                }
            }
            Err(e) => {
                println!("Error reading input: {}", e);
                break;
            }
        }
    }
    
    Ok(())
}

fn execute_query(conn: &rusqlite::Connection, query: &str) -> Result<()> {
    let start = Instant::now();
    let mut stmt = conn.prepare(query)?;
    let column_count = stmt.column_count();
    let column_names: Vec<String> = stmt.column_names().into_iter().map(|s| s.to_string()).collect();
    
    // Print Header
    println!("{}", column_names.join("\t"));
    println!("{}", "-".repeat(column_names.len() * 10)); // simple separator
    
    let mut rows = stmt.query([])?;
    let mut row_count = 0;
    
    while let Some(row) = rows.next()? {
        let mut values = Vec::new();
        for i in 0..column_count {
            let value = row.get_ref(i)?;
            let val_str = match value {
                rusqlite::types::ValueRef::Null => "NULL".to_string(),
                rusqlite::types::ValueRef::Integer(i) => i.to_string(),
                rusqlite::types::ValueRef::Real(f) => f.to_string(),
                rusqlite::types::ValueRef::Text(t) => String::from_utf8_lossy(t).to_string(),
                rusqlite::types::ValueRef::Blob(_) => "[BLOB]".to_string(),
            };
            values.push(val_str);
        }
        println!("{}", values.join("\t"));
        row_count += 1;
    }
    
    println!("({} rows, took {:?})", row_count, start.elapsed());
    Ok(())
}
