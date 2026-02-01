---
name: "flutter-best-practices"
description: "Provides Flutter code standards, architectural patterns, and development tips based on the LKL2 project. Invoke when writing new Flutter code, refactoring, or seeking guidance on project structure."
---

# Flutter Best Practices & Project Standards

This skill outlines the architectural patterns, coding standards, and best practices for the LKL2 project. Follow these guidelines to maintain code quality and consistency.

## 1. Project Architecture (Layered Architecture)

The project follows a clear separation of concerns using a layered architecture:

-   **Data Layer (`lib/data/`)**: Handles data retrieval and storage.
    -   **Repositories (`lib/data/repository/`)**: Abstract data sources (e.g., Rust FFI, Network, Database).
    -   **Pattern**: Use interfaces (e.g., `ILogRepository`) to define contracts. This allows for easier testing and implementation swapping.
    -   **Example**: `LogRepository` wraps `rust_file` calls.

-   **Logic Layer (Providers)**: Manages application state and business logic.
    -   **Location**: Root of `lib/` or `lib/logic/` (if complex).
    -   **State Management**: Use `Provider` (`ChangeNotifier`).
    -   **Responsibility**: Calls Repositories, maintains state, notifies listeners. **Never** put UI code in Providers.

-   **UI Layer (`lib/ui/`)**: Displays data and handles user interactions.
    -   **Pages (`lib/ui/pages/`)**: Top-level screens (e.g., `HomePage`).
    -   **Widgets (`lib/ui/widgets/`)**: Reusable UI components.
    -   **Pattern**: Widgets should be dumb (display data) and delegate logic to Providers.

### Directory Structure
```
lib/
├── data/
│   └── repository/  # Data abstraction
├── ui/
│   ├── pages/       # Full screens
│   └── widgets/     # Reusable components
├── src/
│   └── rust/        # Generated FFI code
├── log_provider.dart # State management
└── main.dart         # Entry point & App configuration
```

## 2. Coding Standards

-   **Linter**: Strictly follow `flutter analyze`. Treat warnings as errors where possible.
-   **Imports**:
    -   Prefer `package:` imports over relative imports for files in other modules.
    -   Group imports: Dart core -> 3rd party packages -> Project files.
-   **Naming**:
    -   Classes: `UpperCamelCase`
    -   Variables/Methods: `lowerCamelCase`
    -   Files: `snake_case.dart`
    -   Private members: Prefix with `_`.
-   **Async/Await**:
    -   Always use `await` for Futures instead of `.then()`.
    -   Handle errors using `try-catch` blocks in the Logic Layer (Providers), not in UI.

## 3. Flutter Development Tips

### State Management (Provider)
-   **Accessing Data**:
    -   `context.watch<T>()`: Use in `build` methods to rebuild on change.
    -   `context.read<T>()`: Use in callbacks (e.g., `onPressed`) to access methods without rebuilding.
-   **Consumer**: Use `Consumer<T>` to wrap only the specific widget that needs rebuilding to optimize performance.

### UI & Layout
-   **Responsive Design**:
    -   Use `Platform.isMacOS` / `Platform.isWindows` to render platform-specific UI (e.g., `PlatformMenuBar` vs `MenuBar`).
    -   Use `LayoutBuilder` if layout needs to change based on window size.
-   **Widget Decomposition**:
    -   Extract complex widgets into smaller, separate files in `lib/ui/widgets/`.
    -   Keep `build` methods clean and readable.
-   **Themes**: Use `Theme.of(context)` to access colors and text styles. Avoid hardcoding colors.

### Rust Integration (FFI)
-   **Abstraction**: Never call Rust FFI functions directly from UI. Wrap them in a Repository.
-   **Types**: Use generated types from `src/rust/` but consider mapping them to Domain models if they become too coupled to FFI specifics.
-   **Initialization**: Ensure `RustLib.init()` is called in `main()` before `runApp()`.

## 4. Common Tasks

### Adding a New Feature
1.  **Define Interface**: Add method to `ILogRepository` (or relevant Repo).
2.  **Implement Data**: Implement method in `LogRepository` (calling Rust FFI).
3.  **Add Logic**: Add method to `LogProvider`, calling the Repository and updating state.
4.  **Create UI**: Create widgets in `lib/ui/widgets/` and bind to Provider.

### Refactoring
-   If a file exceeds 200 lines, consider splitting it.
-   If a widget has too many nested levels, extract sub-widgets.
-   Move logic out of `onPressed` handlers into the Provider.
