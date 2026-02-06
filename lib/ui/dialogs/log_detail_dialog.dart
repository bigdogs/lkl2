import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lkl2/src/rust/file.dart';

class LogDetailDialog extends StatefulWidget {
  final Log log;
  final String content;

  const LogDetailDialog({super.key, required this.log, required this.content});

  @override
  State<LogDetailDialog> createState() => _LogDetailDialogState();
}

class _LogDetailDialogState extends State<LogDetailDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 600,
        height: 500,
        decoration: BoxDecoration(
          color: MacosTheme.of(context).canvasColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: MacosColors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const MacosIcon(
                    CupertinoIcons.info_circle,
                    size: 24,
                    color: MacosColors.systemBlueColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Log Detail #${widget.log.id}",
                    style: MacosTheme.of(context).typography.headline,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: MacosColors.separatorColor),
            // Content
            Expanded(
              child: MacosScrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    widget.content,
                    style: MacosTheme.of(context).typography.body,
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: MacosColors.separatorColor),
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  PushButton(
                    controlSize: ControlSize.regular,
                    secondary: true,
                    onPressed: _copyLine,
                    child: const Text("Copy Line"),
                  ),
                  const SizedBox(width: 8),
                  PushButton(
                    controlSize: ControlSize.regular,
                    secondary: true,
                    onPressed: _copyJson,
                    child: const Text("Copy JSON"),
                  ),
                  const Spacer(),
                  PushButton(
                    controlSize: ControlSize.large,
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
