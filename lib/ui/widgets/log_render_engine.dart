import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lkl2/src/rust/file.dart';

class LogRenderEngine {
  final LogRenderConfig config;

  const LogRenderEngine(this.config);

  static final LogRenderEngine fallback = LogRenderEngine(
    LogRenderConfig.defaultConfig(),
  );

  static final Future<LogRenderEngine> shared = _load();

  static Future<LogRenderEngine> _load() async {
    try {
      // Load from the asset path defined in pubspec.yaml
      final content = await rootBundle.loadString(
        'rust/libparser/rules/lkl2.toml',
      );
      final config = LogRenderConfig.fromToml(content);
      return LogRenderEngine(config);
    } catch (e) {
      debugPrint("Error loading log config: $e");
      return fallback;
    }
  }

  List<Widget> buildCells(BuildContext context, Log log, bool showLineNumbers) {
    final cells = <Widget>[];

    // Prepend line number if enabled
    if (showLineNumbers) {
      cells.add(
        _buildColumn(
          context,
          log,
          const LogColumn(
            width: 50,
            rows: [LogCell(expr: r'$lineNumber', style: 'meta')],
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

  Widget _buildColumn(BuildContext context, Log log, LogColumn col) {
    final widgets = col.rows
        .map((row) => _buildCell(context, log, row))
        .toList();

    final child = col.rows.length == 1
        ? widgets.first
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widgets,
          );

    if (col.width != null) {
      return SizedBox(width: col.width, child: child);
    }
    if (col.flex != null) {
      return Expanded(flex: col.flex!, child: child);
    }
    return Expanded(child: child);
  }

  Widget _buildCell(BuildContext context, Log log, LogCell cell) {
    final text = _evalExpr(log, cell.expr);
    final maxLines = cell.maxLines ?? 1;
    final overflow = cell.ellipsis == false ? null : TextOverflow.ellipsis;

    return _styledText(context, text, cell.style ?? 'text', maxLines, overflow);
  }

  Widget _styledText(
    BuildContext context,
    String text,
    String styleToken,
    int maxLines,
    TextOverflow? overflow,
  ) {
    final token = styleToken.toLowerCase();
    final base = Theme.of(context).textTheme.bodySmall ?? const TextStyle();

    switch (token) {
      case 'tag':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: base.copyWith(color: Colors.grey[700], fontSize: 11),
            maxLines: maxLines,
            overflow: overflow,
          ),
        );
      case 'colortag':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: base.copyWith(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontSize: 11,
            ),
            maxLines: maxLines,
            overflow: overflow,
          ),
        );
      case 'meta':
        return Text(
          text,
          style: base.copyWith(color: Colors.grey, fontSize: 11),
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
    return log.fields[key] ?? '';
  }

  // _formatKv removed as requested

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

class LogRenderConfig {
  final List<LogColumn> columns;

  const LogRenderConfig(this.columns);

  factory LogRenderConfig.defaultConfig() {
    return LogRenderConfig([
      LogColumn(
        width: 180,
        rows: [LogCell(expr: r'time($eventTime)', style: 'meta')],
      ),
      LogColumn(
        flex: 3,
        rows: [LogCell(expr: r'$eventName', style: 'text')],
      ),
    ]);
  }

  factory LogRenderConfig.fromToml(String content) {
    final parsed = _parseColumns(content);
    if (parsed.isEmpty) {
      return LogRenderConfig.defaultConfig();
    }
    return LogRenderConfig(parsed);
  }
}

class LogColumn {
  final double? width;
  final int? flex;
  final List<LogCell> rows;

  const LogColumn({required this.rows, this.width, this.flex});
}

class LogCell {
  final String expr;
  final String? style;
  final int? maxLines;
  final bool? ellipsis;

  const LogCell({required this.expr, this.style, this.maxLines, this.ellipsis});
}

List<LogColumn> _parseColumns(String content) {
  final columns = <_ColumnBuilder>[];
  _ColumnBuilder? currentCol;
  _RowBuilder? currentRow;

  void flushRow() {
    if (currentRow != null && currentCol != null) {
      currentCol!.rows.add(currentRow!);
      currentRow = null;
    }
  }

  void flushCol() {
    if (currentCol != null) {
      flushRow();
      columns.add(currentCol!);
      currentCol = null;
    }
  }

  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    if (line == '[[col]]') {
      flushCol();
      currentCol = _ColumnBuilder();
      continue;
    }
    if (line == '[[col.row]]') {
      if (currentCol == null) {
        continue;
      }
      flushRow();
      currentRow = _RowBuilder();
      continue;
    }
    if (currentCol == null) {
      continue;
    }
    final idx = line.indexOf('=');
    if (idx == -1) {
      continue;
    }
    final key = line.substring(0, idx).trim();
    final value = _stripQuotes(line.substring(idx + 1).trim());

    if (currentRow != null) {
      currentRow!.apply(key, value);
    } else {
      currentCol!.apply(key, value);
    }
  }

  flushCol();

  return columns.map((c) => c.build()).where((c) => c.rows.isNotEmpty).toList();
}

class _ColumnBuilder {
  double? width;
  int? flex;
  String expr = '';
  String style = '';
  final List<_RowBuilder> rows = [];

  void apply(String key, String value) {
    switch (key) {
      case 'width':
        width = double.tryParse(value);
        break;
      case 'flex':
        flex = int.tryParse(value);
        break;
      case 'expr':
        expr = value;
        break;
      case 'style':
        style = value;
        break;
    }
  }

  LogColumn build() {
    final builtRows = rows.isNotEmpty
        ? rows.map((r) => r.build()).toList()
        : [LogCell(expr: expr, style: style.isEmpty ? null : style)];
    final filtered = builtRows.where((r) => r.expr.trim().isNotEmpty).toList();
    return LogColumn(width: width, flex: flex, rows: filtered);
  }
}

class _RowBuilder {
  String expr = '';
  String style = '';
  int? maxLines;
  bool? ellipsis;

  void apply(String key, String value) {
    switch (key) {
      case 'expr':
        expr = value;
        break;
      case 'style':
        style = value;
        break;
      case 'lines':
      case 'maxLines':
        maxLines = int.tryParse(value);
        break;
      case 'ellipsis':
        ellipsis = value.toLowerCase() == 'true';
        break;
    }
  }

  LogCell build() {
    return LogCell(
      expr: expr,
      style: style.isEmpty ? null : style,
      maxLines: maxLines,
      ellipsis: ellipsis,
    );
  }
}

String _stripQuotes(String value) {
  final trimmed = value.trim();
  if (trimmed.length >= 2) {
    final first = trimmed[0];
    final last = trimmed[trimmed.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return trimmed.substring(1, trimmed.length - 1);
    }
  }
  return trimmed;
}
