import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/widgets/log_view_layout.dart';
import 'package:lkl2/src/rust/file.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    if (Platform.isMacOS) {
      return PlatformMenuBar(
        menus: [
          PlatformMenu(
            label: 'File',
            menus: [
              PlatformMenuItem(
                label: 'Open',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyO,
                  meta: true,
                ),
                onSelected: () => provider.pickAndOpenFile(),
              ),
            ],
          ),
          PlatformMenu(
            label: 'View',
            menus: [
              PlatformMenuItem(
                label: provider.showLineNumbers
                    ? 'Hide Line Numbers'
                    : 'Show Line Numbers',
                onSelected: () => provider.toggleLineNumbers(),
              ),
              PlatformMenuItem(
                label: 'Reload',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyR,
                  meta: true,
                ),
                onSelected: () => provider.reload(),
              ),
            ],
          ),
        ],
        child: Scaffold(body: _buildBody(context, provider)),
      );
    } else {
      // Windows / Linux
      return Scaffold(
        body: Column(
          children: [
            MenuBar(
              children: [
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: () => provider.pickAndOpenFile(),
                      shortcut: const SingleActivator(
                        LogicalKeyboardKey.keyO,
                        control: true,
                      ),
                      child: const Text('Open'),
                    ),
                  ],
                  child: const Text('File'),
                ),
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: () => provider.toggleLineNumbers(),
                      child: Text(
                        provider.showLineNumbers
                            ? 'Hide Line Numbers'
                            : 'Show Line Numbers',
                      ),
                    ),
                    MenuItemButton(
                      onPressed: () => provider.reload(),
                      shortcut: const SingleActivator(
                        LogicalKeyboardKey.keyR,
                        control: true,
                      ),
                      child: const Text('Reload'),
                    ),
                  ],
                  child: const Text('View'),
                ),
              ],
            ),
            Expanded(child: _buildBody(context, provider)),
          ],
        ),
      );
    }
  }

  Widget _buildBody(BuildContext context, LogProvider provider) {
    return provider.status.when(
      uninit: () =>
          const Center(child: Text("Drag file or Open file to start")),
      pending: () => const Center(child: Text("Processing file...")),
      error: (msg) => Center(
        child: Text("Error: $msg", style: const TextStyle(color: Colors.red)),
      ),
      complete: () => const LogViewLayout(),
    );
  }
}
