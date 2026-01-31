use serde_json::Value;

pub fn extract_field(root: &Value, path: &str, line: &str, line_no: usize) -> String {
    if path == "$lineno" {
        return line_no.to_string();
    }

    if path == "$line" || path == "$0" {
        return line.to_string();
    }

    let path = if let Some(stripped) = path.strip_prefix("$line.") {
        stripped
    } else if let Some(stripped) = path.strip_prefix("$0.") {
        stripped
    } else {
        return String::new();
    };

    let mut current = root;

    for part in path.split('.') {
        match current {
            Value::Object(map) => {
                if let Some(val) = map.get(part) {
                    current = val;
                } else {
                    return String::new();
                }
            }
            _ => return String::new(),
        }
    }

    match current {
        Value::String(s) => s.clone(),
        Value::Null => String::new(),
        v => v.to_string(),
    }
}
