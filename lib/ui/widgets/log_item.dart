import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/ui/widgets/log_render_engine.dart';

class LogItem extends StatelessWidget {
  final Log log;
  final int index;

  const LogItem({super.key, required this.log, required this.index});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    return FutureBuilder<LogRenderEngine>(
      future: LogRenderEngine.shared,
      builder: (context, snapshot) {
        final engine = snapshot.data ?? LogRenderEngine.fallback;
        // Alternating background color
        final backgroundColor = index.isEven
            ? MacosColors.selectedMenuItemTextColor
            : MacosTheme.of(context).canvasColor;

        return GestureDetector(
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
                log,
                provider.showLineNumbers,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 'detail', child: Text('详细日志')),
        const PopupMenuItem(value: 'copy_line', child: Text('复制一行')),
        const PopupMenuItem(value: 'copy_json', child: Text('复制JSON')),
      ],
    ).then((value) {
      if (!context.mounted) return;

      if (value == 'detail') {
        _showDetail(context, log.id);
      } else if (value == 'copy_line') {
        _copyLine();
      } else if (value == 'copy_json') {
        _copyJson();
      }
    });
  }

  void _copyLine() {
    final fields = log.fields;
    final time = fields["eventTime"] ?? "";
    final name = fields["eventName"] ?? "";
    final line = fields["lineNumber"] ?? log.id.toString();

    final other = fields.entries
        .where((e) => !["eventTime", "eventName", "lineNumber"].contains(e.key))
        .map((e) => "${e.key}:${e.value}")
        .join(" | ");

    final text = "$line $time $name $other";
    Clipboard.setData(ClipboardData(text: text));
  }

  void _copyJson() {
    final json = jsonEncode(log.fields);
    Clipboard.setData(ClipboardData(text: json));
  }

  void _showDetail(BuildContext context, int id) async {
    final provider = context.read<LogProvider>();
    final content = await provider.getDetail(id);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Log Detail #$id"),
          content: SingleChildScrollView(
            child: SelectableText(content ?? "No content"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }
  }
}
