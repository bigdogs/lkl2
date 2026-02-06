import 'package:flutter/widgets.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:lkl2/ui/widgets/main_log_area.dart';
import 'package:lkl2/ui/widgets/bottom_area.dart';
import 'package:macos_ui/macos_ui.dart';

class LogViewLayout extends StatefulWidget {
  const LogViewLayout({super.key});

  @override
  State<LogViewLayout> createState() => _LogViewLayoutState();
}

class _LogViewLayoutState extends State<LogViewLayout> {
  late MultiSplitViewController _controller;
  @override
  void initState() {
    super.initState();
    _controller = MultiSplitViewController(
      areas: [
        Area(data: const MainLogArea(), flex: 6),
        Area(data: const BottomArea(), flex: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 1.0,
        dividerHandleBuffer: 1,
        dividerPainter: DividerPainters.background(
          color: MacosColors.separatorColor.withValues(alpha: 0.2),
          highlightedColor: MacosColors.systemBlueColor,
        ),
      ),
      child: MultiSplitView(
        axis: Axis.vertical,
        controller: _controller,
        builder: (context, area) => area.data as Widget,
      ),
    );
  }
}
