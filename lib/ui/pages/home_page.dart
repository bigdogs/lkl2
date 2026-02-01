import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/widgets/log_view_layout.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/ui/widgets/app_menu.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

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
        child: Scaffold(
          body: DropTarget(
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
          ),
        ),
      );
    } else {
      // Windows / Linux
      return Scaffold(
        body: DropTarget(
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
          child: Column(
            children: [
              AppMenuBuilder.buildMenuBar(menus),
              Expanded(child: _buildBody(context, provider)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildBody(BuildContext context, LogProvider provider) {
    if (_isDragging) {
      return Container(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.file_upload, size: 64, color: Colors.blue),
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
