import 'dart:io';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/theme_provider.dart';
import 'package:lkl2/ui/widgets/file_drop_zone.dart';
import 'package:lkl2/ui/widgets/log_view_layout.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/ui/widgets/app_menu.dart';
import 'package:macos_ui/macos_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MenuGroupData> _buildMenus(BuildContext context, LogProvider provider) {
    final themeProvider = context.watch<ThemeProvider>();
    return [
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
          MenuItemData(
            label: themeProvider.themeMode == ThemeMode.dark
                ? 'Switch to Light Mode'
                : 'Switch to Dark Mode',
            onSelected: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();
    final menus = _buildMenus(context, provider);

    if (Platform.isMacOS) {
      return PlatformMenuBar(
        menus: AppMenuBuilder.buildPlatformMenus(menus),
        child: MacosWindow(
          backgroundColor: MacosTheme.of(context).canvasColor,
          child: MacosScaffold(
            children: [
              ContentArea(
                builder: (context, _) {
                  return FileDropZone(child: _buildBody(context, provider));
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
                return FileDropZone(
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
