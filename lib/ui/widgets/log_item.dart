import 'dart:convert';
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
  final LogRenderEngine engine;

  const LogItem({
    super.key,
    required this.log,
    required this.index,
    required this.engine,
  });

  @override
  State<LogItem> createState() => _LogItemState();
}

class _LogItemState extends State<LogItem> {
  bool _hasSelection = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();
    final engine = widget.engine;

    // Alternating background color
    final isDark = MacosTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = widget.index.isEven
        ? Colors.transparent
        : (isDark ? const Color(0x0FFFFFFF) : const Color(0x08000000));

    return SelectionArea(
      contextMenuBuilder: (context, state) {
        return const SizedBox.shrink();
      },
      onSelectionChanged: (content) {
        final hasSelection = content != null && content.plainText.isNotEmpty;
        if (_hasSelection != hasSelection) {
          setState(() {
            _hasSelection = hasSelection;
          });
        }
      },
      child: Builder(
        builder: (innerContext) {
          return GestureDetector(
            onSecondaryTapDown: (details) {
              // Intercept secondary tap down to prevent SelectionArea from handling it.
            },
            onSecondaryTapUp: (details) {
              _showContextMenu(innerContext, details.globalPosition);
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              decoration: BoxDecoration(color: backgroundColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: engine.buildCells(
                      context,
                      widget.log,
                      provider.showLineNumbers,
                    ),
                  ),
                  if (widget.log.snippet != null)
                    _buildSnippet(context, widget.log.snippet!),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    // Check for selection
    final hasSelection = _hasSelection;

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
              CustomSingleChildLayout(
                delegate: _ContextMenuPositionDelegate(position),
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

  Widget _buildSnippet(BuildContext context, String snippet) {
    final brightness = MacosTheme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Strip tags and find the center position of the first match
    final tagRe = RegExp(r'</?b>');
    final firstBIdx = snippet.indexOf('<b>');
    // Count plain-text chars before the first <b>
    final charsBefore = firstBIdx >= 0
        ? snippet.substring(0, firstBIdx).replaceAll(tagRe, '').length
        : 0;

    // Build spans from tagged string
    List<InlineSpan> spans = [];
    final re = RegExp(r'<b>(.*?)<\/b>');
    int lastMatchEnd = 0;

    for (final match in re.allMatches(snippet)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: snippet.substring(lastMatchEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            backgroundColor: isDark
                ? const Color(0xCC5A3E00)
                : const Color(0xFFFFD54F),
            color: isDark ? const Color(0xFFFFE082) : Colors.black87,
          ),
        ),
      );
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < snippet.length) {
      spans.add(TextSpan(text: snippet.substring(lastMatchEnd)));
    }

    // Use a horizontal ScrollView so we can programmatically center the match
    final scrollController = ScrollController();

    // After layout, scroll to center the match
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      final maxScroll = scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      // Estimate: each char is roughly 7.2px wide in SF Mono 12
      const charWidth = 7.2;
      final matchPixelOffset = charsBefore * charWidth;
      final viewportWidth = scrollController.position.viewportDimension;
      final target = (matchPixelOffset - viewportWidth / 2).clamp(
        0.0,
        maxScroll,
      );
      scrollController.jumpTo(target);
    });

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.only(left: 8, right: 6, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark
                ? MacosColors.systemBlueColor.withValues(alpha: 0.5)
                : MacosColors.systemBlueColor.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        child: Text.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: 'SF Mono',
              fontSize: 11,
              color: const Color(0xFF8E8E93),
            ),
            children: spans,
          ),
          maxLines: 2,
        ),
      ),
    );
  }
}

/// Positions a context menu at the given [position], flipping upward or
/// shifting left when the menu would overflow the overlay bounds.
class _ContextMenuPositionDelegate extends SingleChildLayoutDelegate {
  final Offset position;

  _ContextMenuPositionDelegate(this.position);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double left = position.dx;
    double top = position.dy;

    // Flip upward if the menu would overflow the bottom
    if (top + childSize.height > size.height) {
      top = position.dy - childSize.height;
    }

    // Shift left if the menu would overflow the right edge
    if (left + childSize.width > size.width) {
      left = size.width - childSize.width;
    }

    // Clamp to stay within bounds
    left = left.clamp(0.0, size.width - childSize.width);
    top = top.clamp(0.0, size.height - childSize.height);

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_ContextMenuPositionDelegate oldDelegate) {
    return position != oldDelegate.position;
  }
}
