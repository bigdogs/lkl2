import 'package:flutter/material.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/ui/widgets/log_item.dart';
import 'package:lkl2/ui/widgets/log_render_engine.dart';

class LogList extends StatelessWidget {
  final List<Log> logs;

  const LogList({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center();
    }

    return FutureBuilder<LogRenderEngine>(
      future: LogRenderEngine.shared,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: ProgressCircle());
        }

        final engine = snapshot.data!;
        return ListView.builder(
          prototypeItem: LogItem(log: logs.first, index: 0, engine: engine),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return LogItem(log: log, index: index, engine: engine);
          },
        );
      },
    );
  }
}
