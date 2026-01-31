use anyhow::Result;
use argh::FromArgs;
use libparser::{Engine, QueryResult};
use rustyline::error::ReadlineError;
use rustyline::DefaultEditor;
use std::io::{self, Write};

#[derive(FromArgs)]
#[argh(description = "Log parser CLI")]
struct Args {
    #[argh(positional, description = "path to the log file")]
    file: String,
}

fn main() -> Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    let args: Args = argh::from_env();
    let mut engine = Engine::from_embedded_config()?;
    let stats = engine.load_file(&args.file)?;
    log::info!(
        "Loaded {} lines. Read {:?}, SQLite {:?}, FTS {:?}, Total {:?}",
        stats.inserted_lines,
        stats.read_duration,
        stats.db_duration,
        stats.fts_duration,
        stats.total_duration
    );
    log::info!("Table 'logs' is ready. Columns: {:?}", engine.columns());
    run_repl(&engine)
}

fn run_repl(engine: &Engine) -> Result<()> {
    let mut rl = DefaultEditor::new()?;
    let mut input_buffer = String::new();

    loop {
        let prompt = if input_buffer.is_empty() {
            "> "
        } else {
            "... "
        };
        let readline = rl.readline(prompt);
        match readline {
            Ok(line) => {
                if should_exit(&input_buffer, &line) {
                    break;
                }
                input_buffer.push_str(&line);
                input_buffer.push('\n');

                if line.trim_end().ends_with(';') {
                    rl.add_history_entry(input_buffer.as_str())?;
                    handle_query(engine, &mut io::stdout(), &input_buffer)?;
                    input_buffer.clear();
                }
            }
            Err(ReadlineError::Interrupted) => {
                log::info!("CTRL-C");
                break;
            }
            Err(ReadlineError::Eof) => {
                log::info!("CTRL-D");
                break;
            }
            Err(err) => {
                log::error!("Error: {:?}", err);
                break;
            }
        }
    }
    Ok(())
}

fn should_exit(input_buffer: &str, line_buffer: &str) -> bool {
    if !input_buffer.is_empty() {
        return false;
    }
    let trimmed = line_buffer.trim();
    trimmed.eq_ignore_ascii_case("exit") || trimmed.eq_ignore_ascii_case("quit")
}

fn handle_query(engine: &Engine, stdout: &mut impl Write, query: &str) -> Result<()> {
    match engine.execute_query(query) {
        Ok(result) => print_result(stdout, result),
        Err(e) => {
            write!(stdout, "Error: {}\n", e)?;
            Ok(())
        }
    }
}

fn print_result(stdout: &mut impl Write, result: QueryResult) -> Result<()> {
    write!(stdout, "{}\n", result.headers.join("\t"))?;
    write!(stdout, "{}\n", "-".repeat(result.headers.len() * 10))?;
    for row in &result.rows {
        write!(stdout, "{}\n", row.join("\t"))?;
    }
    write!(
        stdout,
        "({} rows, took {:?})\n",
        result.rows.len(),
        result.duration
    )?;
    Ok(())
}
