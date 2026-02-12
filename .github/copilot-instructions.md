# Copilot Instructions

## Rust Development

### Library Recommendations
If the project involves the following features, use the specified libraries. Do not introduce them if not needed.

1. **Error Management**: `anyhow`, `thiserror`
2. **Command Line**: `argh`
3. **Windows API**: `windows-rs "0.52"`
4. **Logging**: `log-rs` (Initialize at startup)
5. **Embedded Binaries**: `rust-embed = "8.9.0"`

### Basic Principles
1. Code must pass `cargo clippy`. If necessary, use `#[clippy(allow_xxx)]`.
2. Code must satisfy `cargo fmt`.
3. Do not use `.unwrap`, `.expect`, or `unsafe` unless absolutely necessary. If used, you must add comments explaining why it is safe/feasible.
4. When calling Windows APIs, if an error occurs, you must handle the original error information and wrap it as an error to bubble up to the caller.
5. Function call logic and module structure must be clear. In principle, each function should not exceed 40 lines.
6. Code output and error printing must NOT use Chinese.
7. Do not use `println!`, `eprintln!`, etc. Use `log-rs` instead.

### Code Best Practices
1. Keep code concise and logic clear. Try to keep each function under 40 lines.
2. Maintain single responsibility. A function should try to do only one thing.
3. Maintain code readability. Function names should express their meaning.
4. Maintain decoupling. Use design patterns appropriately.
5. If a feature is independent, create a new module in an appropriate directory. Do not put all code in one file.

---

## Flutter Development

### Project Architecture (Layered Architecture)
- **Data Layer (`lib/data/`)**: Handles data retrieval (Repositories).
- **Logic Layer (Providers)**: Manages state using `Provider`. Calls repositories. **No UI code here.**
- **UI Layer (`lib/ui/`)**: Displays data. **Widgets must be dumb.**

### Structural Organization
- **One Widget per File**: If a widget class is not private `_Widget`, it generally belongs in its own file.
- **Complex Private Widgets**: If a private widget exceeds ~50 lines or handles distinct logic, extract it to a separate file.
- **Dialogs/Modals**: Always extract into separate files (e.g., `lib/ui/dialogs/`).
- **File Naming**: Use snake_case matching class name (e.g., `LogDetailDialog` -> `log_detail_dialog.dart`).

### macOS UI Style Guide (`macos_ui`)
1. **Package**: MUST use `macos_ui` widgets (not Material/Cupertino) where possible.
2. **Icons**: Use `CupertinoIcons`.
3. **Structure**: Top-level pages use `MacosWindow` -> `MacosScaffold`.
4. **Typography**: `MacosTheme.of(context).typography`.
5. **Colors**: Use `MacosColors` system colors which automatically adapt to Light/Dark modes. Avoid hardcoded colors.
6. **Hover**: Use `MouseRegion` with `MacosColors.systemBlueColor.withValues(alpha: 0.18)`.

### Coding Standards
- Fix all linter warnings.
- Use `package:` imports.
- Use `await`, handle errors in Providers.
- Split files > 200 lines. Extract nested trees.
- **Build Verification**: After making code changes, verify compilation:
  - On macOS: `flutter build macos --debug`
  - On Windows: `flutter build windows --debug`
