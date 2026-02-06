import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/ui/widgets/log_render_engine.dart';
import 'package:lkl2/ui/dialogs/log_detail_dialog.dart';
import 'package:lkl2/ui/widgets/log/log_context_menu.dart';

class LogItem extends StatefulWidget {
  final Log log;
  final int index;

  const LogItem({super.key, required this.log, required this.index});

  @override
  State<LogItem> createState() => _LogItemState();
}

class _LogItemState extends State<LogItem> {
  SelectableRegionState? _selectableRegion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectableRegion = context
        .findAncestorStateOfType<SelectableRegionState>();
  }

  @override
  void dispose() {
    // WORKAROUND: Clear selection when the item is scrolled out of view/disposed.
    // This prevents SelectionArea from holding onto invalid geometries which causes crashes
    // (Issue #126023).
    // The user accepted this behavior: "If the selected area leaves the visible area, clear selection".
    try {
      if (_selectableRegion != null && _selectableRegion!.mounted) {
        // We only clear if there is actually a selection to avoid unnecessary updates
        // But we can't easily check if *this* item is selected.
        // So we clear if there is ANY selection.
        // This means scrolling will clear selection.

        // Defer the clearSelection to the next frame to avoid "setState() or markNeedsBuild() called during build"
        // This happens because dispose() is called during the build phase of the parent/ancestor.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_selectableRegion != null && _selectableRegion!.mounted) {
            _selectableRegion!.clearSelection();
          }
        });
      }
    } catch (e) {
      debugPrint("Error clearing selection on dispose: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    return FutureBuilder<LogRenderEngine>(
      future: LogRenderEngine.shared,
      builder: (context, snapshot) {
        final engine = snapshot.data ?? LogRenderEngine.fallback;
        // Alternating background color
        final backgroundColor = widget.index.isEven
            ? MacosColors.selectedMenuItemTextColor
            : MacosTheme.of(context).canvasColor;

        return GestureDetector(
          onSecondaryTapDown: (details) {
            // Intercept secondary tap down to prevent SelectionArea from handling it.
            // SelectionArea triggers _handleRightClickDown -> _selectWordAt which causes a crash.
          },
          onSecondaryTapUp: (details) {
            _showContextMenu(context, details.globalPosition);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: backgroundColor),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: engine.buildCells(
                context,
                widget.log,
                provider.showLineNumbers,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    // Check for selection
    final hasSelection = context.read<LogProvider>().hasSelection;

    void close() {
      entry.remove();
    }

    void onSelected(String value) {
      close();
      if (!context.mounted) return;
      if (value == 'detail') {
        _showDetail(context, widget.log.id);
      } else if (value == 'copy_line') {
        _copyLine();
      } else if (value == 'copy_json') {
        _copyJson();
      } else if (value == 'copy_selection') {
        _safeCopySelection(context);
      }
    }

    entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                onTap: close,
                behavior: HitTestBehavior.translucent,
              ),
              Positioned(
                left: position.dx,
                top: position.dy,
                child: LogContextMenu(
                  onSelected: onSelected,
                  hasSelection: hasSelection,
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(entry);
  }

  void _safeCopySelection(BuildContext context) {
    try {
      // Try to copy using the intent system safely
      final result = Actions.maybeInvoke(context, CopySelectionTextIntent.copy);
      if (result == null) {
        debugPrint("Copy action not found or handled.");
      }
    } catch (e) {
      debugPrint("Failed to copy selection: $e");
      // If copy fails, suppress the crash as requested
    }
  }

  void _copyLine() {
    final fields = widget.log.fields;
    final time = fields["eventTime"] ?? "";
    final name = fields["eventName"] ?? "";
    final line = fields["lineNumber"] ?? widget.log.id.toString();

    final other = fields.entries
        .where((e) => !["eventTime", "eventName", "lineNumber"].contains(e.key))
        .map((e) => "${e.key}:${e.value}")
        .join(" | ");

    final text = "$line $time $name $other";
    Clipboard.setData(ClipboardData(text: text));
  }

  void _copyJson() {
    final json = jsonEncode(widget.log.fields);
    Clipboard.setData(ClipboardData(text: json));
  }

  void _showDetail(BuildContext context, int id) async {
    final provider = context.read<LogProvider>();
    final content = await provider.getDetail(id);

    if (context.mounted) {
      showMacosAlertDialog(
        context: context,
        builder: (context) =>
            LogDetailDialog(log: widget.log, content: content ?? "No content"),
      );
    }
  }
}
