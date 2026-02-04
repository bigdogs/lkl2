import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/widgets/log_list.dart';

class MainLogArea extends StatelessWidget {
  const MainLogArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    return Column(
      children: [Expanded(child: LogList(logs: provider.logs))],
    );
  }
}
