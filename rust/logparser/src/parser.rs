use serde_json::Value;

pub fn extract_field(root: &Value, path: &str) -> String {
    if path == "$0" {
        return root.to_string();
    }
    
    let parts: Vec<&str> = if path.starts_with("$0.") {
        path["$0.".len()..].split('.').collect()
    } else {
        // If it doesn't start with $0., assume it's relative or invalid. 
        // For now return empty or try to traverse?
        // Given the spec, let's assume it always starts with $0
        return String::new();
    };

    let mut current = root;
    
    for part in parts {
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
