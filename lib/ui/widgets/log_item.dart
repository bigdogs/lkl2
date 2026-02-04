import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/ui/widgets/log_render_engine.dart';

class LogItem extends StatelessWidget {
  final Log log;
  final int index;

  const LogItem({super.key, required this.log, required this.index});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    return FutureBuilder<LogRenderEngine>(
      future: LogRenderEngine.shared,
      builder: (context, snapshot) {
        final engine = snapshot.data ?? LogRenderEngine.fallback;
        // Alternating background color
        final backgroundColor = index.isEven
            ? MacosColors.selectedMenuItemTextColor
            : MacosTheme.of(context).canvasColor;

        return GestureDetector(
          onSecondaryTapUp: (details) {
            _showContextMenu(context, details.globalPosition);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: backgroundColor),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: engine.buildCells(
                context,
                log,
                provider.showLineNumbers,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    void close() {
      entry.remove();
    }

    void onSelected(String value) {
      close();
      if (!context.mounted) return;
      if (value == 'detail') {
        _showDetail(context, log.id);
      } else if (value == 'copy_line') {
        _copyLine();
      } else if (value == 'copy_json') {
        _copyJson();
      }
    }

    entry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              GestureDetector(
                onTap: close,
                behavior: HitTestBehavior.translucent,
              ),
              Positioned(
                left: position.dx,
                top: position.dy,
                child: _LogContextMenu(onSelected: onSelected),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(entry);
  }

  void _copyLine() {
    final fields = log.fields;
    final time = fields["eventTime"] ?? "";
    final name = fields["eventName"] ?? "";
    final line = fields["lineNumber"] ?? log.id.toString();

    final other = fields.entries
        .where((e) => !["eventTime", "eventName", "lineNumber"].contains(e.key))
        .map((e) => "${e.key}:${e.value}")
        .join(" | ");

    final text = "$line $time $name $other";
    Clipboard.setData(ClipboardData(text: text));
  }

  void _copyJson() {
    final json = jsonEncode(log.fields);
    Clipboard.setData(ClipboardData(text: json));
  }

  void _showDetail(BuildContext context, int id) async {
    final provider = context.read<LogProvider>();
    final content = await provider.getDetail(id);

    if (context.mounted) {
      showMacosAlertDialog(
        context: context,
        builder: (context) => MacosAlertDialog(
          appIcon: const MacosIcon(
            CupertinoIcons.info_circle,
            size: 32,
            color: MacosColors.systemBlueColor,
          ),
          title: Text("Log Detail #$id"),
          message: SingleChildScrollView(child: Text(content ?? "No content")),
          primaryButton: PushButton(
            controlSize: ControlSize.large,
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ),
      );
    }
  }
}

class _LogContextMenu extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _LogContextMenu({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    const items = [
      _ContextMenuItemData(value: 'detail', label: '详细日志'),
      _ContextMenuItemData(value: 'copy_line', label: '复制一行'),
      _ContextMenuItemData(value: 'copy_json', label: '复制JSON'),
    ];

    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MacosColors.separatorColor),
        boxShadow: const [
          BoxShadow(
            color: MacosColors.systemGrayColor,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items
            .map(
              (item) => _ContextMenuItemRow(item: item, onSelected: onSelected),
            )
            .toList(),
      ),
    );
  }
}

class _ContextMenuItemData {
  final String value;
  final String label;

  const _ContextMenuItemData({required this.value, required this.label});
}

class _ContextMenuItemRow extends StatefulWidget {
  final _ContextMenuItemData item;
  final ValueChanged<String> onSelected;

  const _ContextMenuItemRow({required this.item, required this.onSelected});

  @override
  State<_ContextMenuItemRow> createState() => _ContextMenuItemRowState();
}

class _ContextMenuItemRowState extends State<_ContextMenuItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = MacosTheme.of(context);
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelected(widget.item.value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: _isHovered
              ? MacosColors.systemBlueColor.withValues(alpha: 0.18)
              : MacosColors.transparent,
          child: Text(
            widget.item.label,
            style: theme.typography.body.copyWith(
              color: MacosColors.labelColor.resolveFrom(context),
            ),
          ),
        ),
      ),
    );
  }
}
