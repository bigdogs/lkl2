---
name: "flutter-best-practices"
description: "Provides Flutter code standards, macOS UI guidelines, and architectural patterns. Invoke when writing UI code, refactoring, or ensuring project consistency."
---

# Flutter Best Practices & Style Guide

This skill combines architectural standards, macOS UI guidelines, and structural best practices for the LKL2 project.

## 1. Project Architecture (Layered Architecture)

-   **Data Layer (`lib/data/`)**: Handles data retrieval (Repositories).
-   **Logic Layer (Providers)**: Manages state using `Provider`. Calls repositories. **No UI code here.**
-   **UI Layer (`lib/ui/`)**: Displays data. **Widgets must be dumb.**

## 2. Structural Organization (Componentization)

**Constraint**: Independent features MUST be extracted into independent components in their own files.

-   **One Widget per File**: If a widget class is not private `_Widget`, it generally belongs in its own file.
-   **Complex Private Widgets**: If a private widget `_SubWidget` exceeds ~50 lines or handles distinct logic, extract it to a separate file in `lib/ui/widgets/` or a feature-specific subdirectory.
-   **Dialogs/Modals**: Always extract Dialogs, BottomSheets, and complex ContextMenus into separate files (e.g., `lib/ui/dialogs/`).
-   **File Naming**: Use snake_case. Matches class name (e.g., `LogDetailDialog` -> `log_detail_dialog.dart`).

## 3. macOS UI Style Guide (`macos_ui`)

**Core Constraints**:
1.  **Package**: MUST use `macos_ui` widgets (not Material/Cupertino) where possible.
2.  **Icons**: Use `CupertinoIcons`.
3.  **Structure**: Top-level pages use `MacosWindow` -> `MacosScaffold`.

**Widget Mapping**:
| Material | macOS UI |
| :--- | :--- |
| `Scaffold` | `MacosScaffold` |
| `AppBar` | `ToolBar` |
| `ElevatedButton` | `PushButton` |
| `TextField` | `MacosTextField` |
| `AlertDialog` | `MacosAlertDialog` (or custom `Center` container for size control) |

**Styling**:
-   **Typography**: `MacosTheme.of(context).typography`.
-   **Colors**: `MacosColors.labelColor`, `MacosColors.systemBlueColor`.
-   **Theme Awareness**: All colors MUST support both Light and Dark modes.
    -   Use `MacosColors` system colors (e.g., `systemBlueColor`, `labelColor`) which automatically adapt.
    -   Avoid hardcoded colors like `Colors.white` or `Colors.black`.
    -   Test UI in both themes to ensure contrast and visibility.
-   **Hover**: Use `MouseRegion` with `MacosColors.systemBlueColor.withValues(alpha: 0.18)`.

## 4. Coding Standards

-   **Linter**: Fix all warnings.
-   **Imports**: `package:` imports preferred.
-   **Async**: Use `await`, handle errors in Providers.
-   **Refactoring**: Split files > 200 lines. Extract nested trees.
-   **Build Verification**: After making code changes, you MUST verify that the project compiles successfully.
    -   On Windows, run: `flutter build windows --debug`
    -   On macOS, run: `flutter build macos --debug`
