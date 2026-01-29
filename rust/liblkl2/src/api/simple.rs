use std::fs::File;
use std::io::{BufReader, Read, Seek, SeekFrom};
use std::sync::Mutex;
use anyhow::{Context, Result};
use once_cell::sync::Lazy;

struct LogState {
    file_path: String,
    // Store offsets of each line start. 
    // line_offsets[i] = byte offset where line i starts.
    line_offsets: Vec<u64>,
    total_size: u64,
}

// Global state to hold the currently opened file
static STATE: Lazy<Mutex<Option<LogState>>> = Lazy::new(|| Mutex::new(None));

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

/// Open a file and build the line index.
/// This might take a few seconds for very large files.
pub fn open_file(path: String) -> Result<u64> {
    let file = File::open(&path).context("Failed to open file")?;
    let total_size = file.metadata()?.len();
    
    // Build index
    let mut reader = BufReader::new(file);
    let mut line_offsets = Vec::new();
    let mut current_offset = 0;
    
    // The first line always starts at 0
    line_offsets.push(0);
    
    // We scan the file for newlines to build the index
    // Using a buffer to speed up scanning
    let mut buffer = [0u8; 8192]; // 8KB buffer
    
    loop {
        let bytes_read = reader.read(&mut buffer)?;
        if bytes_read == 0 {
            break;
        }
        
        for i in 0..bytes_read {
            if buffer[i] == b'\n' {
                // The NEXT line starts at current_offset + i + 1
                line_offsets.push(current_offset + (i as u64) + 1);
            }
        }
        
        current_offset += bytes_read as u64;
    }

    // If the file doesn't end with a newline, the last line is covered by the last start offset.
    // If the last character was a newline, we pushed an offset that points to EOF, which acts as an empty last line or just EOF marker.
    // Let's adjust: if the last offset is exactly EOF, remove it, unless the file is empty.
    if !line_offsets.is_empty() {
        if let Some(last) = line_offsets.last() {
            if *last >= total_size && line_offsets.len() > 1 {
                 line_offsets.pop();
            }
        }
    }
    
    let line_count = line_offsets.len() as u64;

    let state = LogState {
        file_path: path,
        line_offsets,
        total_size,
    };

    let mut guard = STATE.lock().unwrap();
    *guard = Some(state);

    Ok(line_count)
}

/// Get the total number of lines in the currently opened file
pub fn get_total_lines() -> Result<u64> {
    let guard = STATE.lock().unwrap();
    if let Some(state) = &*guard {
        Ok(state.line_offsets.len() as u64)
    } else {
        Ok(0)
    }
}

/// Read a specific range of lines
pub fn read_lines(start_line_index: u64, count: u64) -> Result<Vec<String>> {
    let mut guard = STATE.lock().unwrap();
    let state = guard.as_mut().context("No file opened")?;
    
    let total_lines = state.line_offsets.len() as u64;
    if start_line_index >= total_lines {
        return Ok(Vec::new());
    }
    
    let end_line_index = (start_line_index + count).min(total_lines);
    let mut result = Vec::with_capacity((end_line_index - start_line_index) as usize);
    
    let mut file = File::open(&state.file_path)?;
    
    for i in start_line_index..end_line_index {
        let start_offset = state.line_offsets[i as usize];
        let end_offset = if (i as usize) + 1 < state.line_offsets.len() {
            state.line_offsets[(i as usize) + 1]
        } else {
            state.total_size
        };
        
        let len = end_offset - start_offset;
        // Avoid reading insanely large lines if they exist (though we support big files, a single 1GB line is tricky)
        // Let's cap line length reading for safety if needed, but for now read full.
        
        if len == 0 {
             result.push("".to_string());
             continue;
        }

        // Seek and read
        file.seek(SeekFrom::Start(start_offset))?;
        let mut buffer = vec![0u8; len as usize];
        file.read_exact(&mut buffer)?;
        
        // Convert to string (lossy to handle non-utf8 logs gracefully)
        let s = String::from_utf8_lossy(&buffer).to_string();
        // Remove trailing newline if present, as UI usually handles line breaks
        let s = if s.ends_with('\n') {
            if s.ends_with("\r\n") {
                s[..s.len()-2].to_string()
            } else {
                s[..s.len()-1].to_string()
            }
        } else {
            s.to_string()
        };
        
        result.push(s);
    }
    
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn test_log_read() -> Result<()> {
        let path = "test_log.txt";
        let mut file = File::create(path)?;
        writeln!(file, "Line 1")?;
        writeln!(file, "Line 2")?;
        writeln!(file, "Line 3")?;
        file.flush()?;

        let count = open_file(path.to_string())?;
        assert_eq!(count, 3);

        let lines = read_lines(0, 3)?;
        assert_eq!(lines[0], "Line 1");
        assert_eq!(lines[1], "Line 2");
        assert_eq!(lines[2], "Line 3");

        let lines_partial = read_lines(1, 1)?;
        assert_eq!(lines_partial.len(), 1);
        assert_eq!(lines_partial[0], "Line 2");

        std::fs::remove_file(path)?;
        Ok(())
    }
}
