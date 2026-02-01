import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/src/rust/file.dart';

class LogItem extends StatelessWidget {
  final Log log;

  const LogItem({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();
    final fields = log.fields;
    final time = fields["eventTime"] ?? "";
    final name = fields["eventName"] ?? "";
    final line = fields["lineNumber"] ?? log.id.toString();

    return InkWell(
      onTap: () {
        _showDetail(context, log.id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.showLineNumbers)
              SizedBox(
                width: 50,
                child: Text(
                  line,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            SizedBox(
              width: 180,
              child: Text(
                time,
                style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    fields.entries
                        .where(
                          (e) => ![
                            "eventTime",
                            "eventName",
                            "lineNumber",
                          ].contains(e.key),
                        )
                        .map((e) => "${e.key}:${e.value}")
                        .join(" | "),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
