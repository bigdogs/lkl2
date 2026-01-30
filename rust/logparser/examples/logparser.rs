use anyhow::Result;
use argh::FromArgs;
use logparser::{Engine, QueryResult};
use std::io::{self, Write};

#[derive(FromArgs)]
#[argh(description = "Log parser CLI")]
struct Args {
    #[argh(positional, description = "path to the log file")]
    file: String,
}

fn main() -> Result<()> {
    env_logger::init();
    let args: Args = argh::from_env();
    let mut engine = Engine::from_embedded_config()?;
    let stats = engine.load_file(&args.file)?;
    log::info!(
        "Loaded {} lines. Read {:?}, SQLite {:?}, Total {:?}",
        stats.inserted_lines,
        stats.read_duration,
        stats.db_duration,
        stats.total_duration
    );
    log::info!("Table 'logs' is ready. Columns: {:?}", engine.columns());
    run_repl(&engine)
}

fn run_repl(engine: &Engine) -> Result<()> {
    let stdin = io::stdin();
    let mut stdout = io::stdout();
    let mut input_buffer = String::new();
    let mut line_buffer = String::new();

    loop {
        print_prompt(&mut stdout, &input_buffer)?;
        line_buffer.clear();
        let read = stdin.read_line(&mut line_buffer)?;
        if read == 0 {
            break;
        }
        if should_exit(&input_buffer, &line_buffer) {
            break;
        }
        input_buffer.push_str(&line_buffer);
        if line_buffer.trim_end().ends_with(';') {
            handle_query(engine, &mut stdout, &input_buffer)?;
            input_buffer.clear();
        }
    }
    Ok(())
}

fn print_prompt(stdout: &mut impl Write, input_buffer: &str) -> Result<()> {
    if input_buffer.is_empty() {
        write!(stdout, "> ")?;
    } else {
        write!(stdout, "... ")?;
    }
    stdout.flush()?;
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
