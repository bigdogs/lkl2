import 'package:flutter/cupertino.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lkl2/src/rust/file.dart';

class LogRenderEngine {
  final RenderConfig config;

  const LogRenderEngine(this.config);

  static final Future<LogRenderEngine> shared = _load();

  static Future<LogRenderEngine> _load() async {
    final config = await getRenderConfig();
    return LogRenderEngine(config);
  }

  List<Widget> buildCells(BuildContext context, Log log, bool showLineNumbers) {
    final cells = <Widget>[];

    // Prepend line number if enabled
    if (showLineNumbers) {
      cells.add(
        _buildColumn(
          context,
          log,
          const RenderColumn(
            width: 50,
            rows: [
              RenderCell(expr: r'$lineNumber', style: 'meta', elements: []),
            ],
          ),
        ),
      );
    }

    // Add configured columns
    cells.addAll(config.columns.map((col) => _buildColumn(context, log, col)));

    if (cells.isEmpty) return [];

    final spaced = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      spaced.add(cells[i]);
      if (i < cells.length - 1) {
        spaced.add(
          const SizedBox(width: 16),
        ); // Increase padding between columns
      }
    }
    return spaced;
  }

  Widget _buildColumn(BuildContext context, Log log, RenderColumn col) {
    final widgets = col.rows
        .map((row) => _buildCell(context, log, row))
        .toList();

    CrossAxisAlignment crossAlign = CrossAxisAlignment.start;
    if (col.align == 'center') {
      crossAlign = CrossAxisAlignment.center;
    } else if (col.align == 'right') {
      crossAlign = CrossAxisAlignment.end;
    }

    Widget child;
    if (col.rows.length == 1) {
      child = widgets.first;
      if (col.align != null) {
        child = Align(alignment: _toAlignment(col.align), child: child);
      }
    } else {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAlign,
        children: widgets,
      );
    }

    if (col.width != null) {
      return SizedBox(width: col.width, child: child);
    }
    if (col.flex != null) {
      return Expanded(flex: col.flex!, child: child);
    }
    return Expanded(child: child);
  }

  Alignment _toAlignment(String? align) {
    if (align == 'center') return Alignment.center;
    if (align == 'right') return Alignment.centerRight;
    return Alignment.centerLeft;
  }

  Widget _buildCell(BuildContext context, Log log, RenderCell cell) {
    if (cell.elements.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: cell.elements.asMap().entries.map((entry) {
          final index = entry.key;
          final e = entry.value;
          final widget = _buildElement(context, log, e);
          if (index < cell.elements.length - 1) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: widget,
            );
          }
          return widget;
        }).toList(),
      );
    }

    final text = _evalExpr(log, cell.expr ?? '');
    final maxLines = cell.maxLines ?? 1;
    final overflow = cell.ellipsis == false ? null : TextOverflow.ellipsis;

    return _styledText(context, text, cell.style ?? 'text', maxLines, overflow);
  }

  Widget _buildElement(BuildContext context, Log log, RenderElement element) {
    final text = _evalExpr(log, element.expr);
    return _styledText(
      context,
      text,
      element.style ?? 'text',
      1,
      TextOverflow.ellipsis,
    );
  }

  Widget _styledText(
    BuildContext context,
    String text,
    String styleToken,
    int maxLines,
    TextOverflow? overflow,
  ) {
    final token = styleToken.toLowerCase();
    final base = MacosTheme.of(context).typography.body.copyWith(fontSize: 12);

    switch (token) {
      case 'tag':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: MacosColors.systemGrayColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: base.copyWith(
              color: MacosColors.labelColor.resolveFrom(context),
              fontSize: 11,
            ),
            maxLines: maxLines,
            overflow: overflow,
          ),
        );
      case 'colortag':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: MacosColors.systemBlueColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: base.copyWith(
              color: MacosColors.systemBlueColor,
              fontSize: 11,
            ),
            maxLines: maxLines,
            overflow: overflow,
          ),
        );
      case 'meta':
        return Text(
          text,
          style: base.copyWith(
            color: MacosColors.secondaryLabelColor.resolveFrom(context),
            fontSize: 11,
          ),
          maxLines: maxLines,
          overflow: overflow,
        );
      case 'text':
      default:
        return Text(text, style: base, maxLines: maxLines, overflow: overflow);
    }
  }

  String _evalExpr(Log log, String expr) {
    final trimmed = expr.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith(r'$')) {
      return _resolveField(log, trimmed.substring(1));
    }
    if (trimmed.startsWith('time(') && trimmed.endsWith(')')) {
      final inner = trimmed.substring(5, trimmed.length - 1);
      return _formatTime(_evalExpr(log, inner));
    }
    return trimmed;
  }

  String _resolveField(Log log, String key) {
    // Handle nested fields like "$line.Event.platformUtcTime"
    // But currently Rust Log struct has fields: Map<String, String>.
    // The keys in the map match what was parsed in Rust.
    // In lkl2.toml: `eventTime = "$line.Event.paltformUtcTime"`
    // The key in fields map is "eventTime".
    // The expression in column is `time($eventTime)`.
    // So `_resolveField` receives "eventTime".
    return log.fields[key] ?? '';
  }

  String _formatTime(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return '';
    }
    final asInt = int.tryParse(value);
    DateTime? time;
    if (asInt != null) {
      final millis = value.length <= 10 ? asInt * 1000 : asInt;
      time = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
    } else {
      time = DateTime.tryParse(value)?.toLocal();
    }
    if (time == null) {
      return value;
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
