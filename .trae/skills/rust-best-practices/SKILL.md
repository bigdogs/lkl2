---
name: "rust-best-practices"
description: "Provides Rust coding standards, library recommendations, and best practices based on project rules. Invoke when writing or reviewing Rust code."
---

# Rust Development Best Practices

This skill provides guidelines for Rust development in this project, including library recommendations, basic principles, and coding best practices.

## Library Recommendations
If the project involves the following features, use the specified libraries. Do not introduce them if not needed.

1. **Error Management**: `anyhow`, `thiserror`
2. **Command Line**: `argh`
3. **Windows API**: `windows-rs "0.52"`
4. **Logging**: `log-rs` (Initialize at startup)
5. **Embedded Binaries**: `rust-embed = "8.9.0"`

## Basic Principles
1. Code must pass `cargo clippy`. If necessary, use `#[clippy(allow_xxx)]`.
2. Code must satisfy `cargo fmt`.
3. Do not use `.unwrap`, `.expect`, or `unsafe` unless absolutely necessary. If used, you must add comments explaining why it is safe/feasible.
4. When calling Windows APIs, if an error occurs, you must handle the original error information and wrap it as an error to bubble up to the caller.
5. Function call logic and module structure must be clear. In principle, each function should not exceed 40 lines.
6. Code output and error printing must NOT use Chinese.
7. Do not use `println!`, `eprintln!`, etc. Use `log-rs` instead.

## Code Best Practices
1. Keep code concise and logic clear. Try to keep each function under 40 lines.
2. Maintain single responsibility. A function should try to do only one thing.
3. Maintain code readability. Function names should express their meaning.
4. Maintain decoupling. Use design patterns appropriately.
