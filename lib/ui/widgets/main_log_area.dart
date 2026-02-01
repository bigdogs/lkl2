import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/widgets/log_list.dart';

class MainLogArea extends StatelessWidget {
  const MainLogArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Row(
            children: [
              Text("Main Logs", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(child: LogList(logs: provider.logs)),
      ],
    );
  }
}
