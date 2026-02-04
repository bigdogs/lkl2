import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/widgets/log_view_layout.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/ui/widgets/app_menu.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:macos_ui/macos_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    final menus = [
      MenuGroupData(
        label: 'File',
        items: [
          MenuItemData(
            label: 'Open',
            onSelected: () => provider.pickAndOpenFile(),
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyO,
              meta: true,
              control: true, // Handle both for cross-platform
            ),
          ),
        ],
      ),
      MenuGroupData(
        label: 'View',
        items: [
          MenuItemData(
            label: provider.showLineNumbers
                ? 'Hide Line Numbers'
                : 'Show Line Numbers',
            onSelected: () => provider.toggleLineNumbers(),
          ),
          MenuItemData(
            label: 'Reload',
            onSelected: () => provider.reload(),
            shortcut: const SingleActivator(
              LogicalKeyboardKey.keyR,
              meta: true,
              control: true,
            ),
          ),
        ],
      ),
    ];

    if (Platform.isMacOS) {
      return PlatformMenuBar(
        menus: AppMenuBuilder.buildPlatformMenus(menus),
        child: MacosWindow(
          backgroundColor: MacosTheme.of(context).canvasColor,
          child: MacosScaffold(
            toolBar: const ToolBar(title: Text('LKL2 Log Viewer')),
            children: [
              ContentArea(
                builder: (context, _) {
                  return DropTarget(
                    onDragDone: (detail) async {
                      if (detail.files.isNotEmpty) {
                        await provider.openLogFile(detail.files.first.path);
                      }
                    },
                    onDragEntered: (detail) {
                      setState(() {
                        _isDragging = true;
                      });
                    },
                    onDragExited: (detail) {
                      setState(() {
                        _isDragging = false;
                      });
                    },
                    child: _buildBody(context, provider),
                  );
                },
              ),
            ],
          ),
        ),
      );
    } else {
      // Windows / Linux
      return MacosWindow(
        child: MacosScaffold(
          children: [
            ContentArea(
              minWidth: 0,
              builder: (context, scrollController) {
                return DropTarget(
                  onDragDone: (detail) async {
                    if (detail.files.isNotEmpty) {
                      await provider.openLogFile(detail.files.first.path);
                    }
                  },
                  onDragEntered: (detail) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onDragExited: (detail) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  child: Container(
                    color: MacosTheme.of(context).canvasColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppMenuBuilder.buildMenuBar(menus),
                        Expanded(child: _buildBody(context, provider)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildBody(BuildContext context, LogProvider provider) {
    if (_isDragging) {
      return Container(
        color: MacosTheme.of(context).primaryColor.withValues(alpha: 0.1),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              MacosIcon(
                CupertinoIcons.doc_on_clipboard,
                size: 64,
                color: MacosColors.systemBlueColor,
              ),
              SizedBox(height: 16),
              Text(
                "Release to open file",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return provider.status.when(
      uninit: () => const Center(
        child: Text(
          "Drag file or Open file to start",
          style: TextStyle(color: MacosColors.systemGrayColor),
        ),
      ),
      pending: () => const Center(child: ProgressCircle()),
      error: (msg) => Center(
        child: Text(
          "Error: $msg",
          style: const TextStyle(color: MacosColors.systemRedColor),
        ),
      ),
      complete: () => const LogViewLayout(),
    );
  }
}
