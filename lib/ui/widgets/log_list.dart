import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/ui/widgets/log_item.dart';

class LogList extends StatelessWidget {
  final List<Log> logs;

  const LogList({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center();
    }

    return SelectionArea(
      contextMenuBuilder: (context, state) {
        return const SizedBox.shrink();
      },
      onSelectionChanged: (content) {
        final hasSelection = content != null && content.plainText.isNotEmpty;
        context.read<LogProvider>().setSelection(hasSelection);
      },
      child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return LogItem(log: log, index: index);
        },
      ),
    );
  }
}
