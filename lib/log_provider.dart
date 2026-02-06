import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/data/repository/log_repository.dart';

enum FilterMode {
  equals,
  contains;

  String toSql(String field, String value) {
    // Basic sanitization to prevent breaking the SQL string
    final sanitized = value.replaceAll("'", "''");
    switch (this) {
      case FilterMode.equals:
        return "$field = '$sanitized'";
      case FilterMode.contains:
        return "$field LIKE '%$sanitized%'";
    }
  }

  String get label {
    switch (this) {
      case FilterMode.equals:
        return "Equals";
      case FilterMode.contains:
        return "Contains";
    }
  }
}

class FilterCondition {
  final String field;
  final FilterMode mode;
  final String value;

  FilterCondition({
    required this.field,
    required this.mode,
    required this.value,
  });
}

class LogProvider extends ChangeNotifier {
  final ILogRepository _repository;

  LogProvider({ILogRepository? repository})
    : _repository = repository ?? LogRepository();

  FileStatus _status = const FileStatus.uninit();
  List<Log> _logs = [];
  int _totalCount = 0;

  // Filter/Search
  String _filterSql = "";
  final List<FilterCondition> _filters = [];
  String _lastSearchQuery = "";

  List<FilterCondition> get filters => _filters;
  String get lastSearchQuery => _lastSearchQuery;

  // String _ftsQuery = "";

  // Search Results (Bottom Panel)
  List<Log> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  // UI State
  bool _showLineNumbers = true;
  String? _currentFilePath;
  bool _hasSelection = false;

  Timer? _statusTimer;

  FileStatus get status => _status;
  List<Log> get logs => _logs;
  int get totalCount => _totalCount;
  List<Log> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  bool get showLineNumbers => _showLineNumbers;
  String? get currentFilePath => _currentFilePath;
  bool get hasSelection => _hasSelection;

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> pickAndOpenFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      await openLogFile(result.files.single.path!);
    }
  }

  Future<void> openLogFile(String path) async {
    _status = const FileStatus.pending();
    _logs = [];
    _searchResults = [];
    _totalCount = 0;
    notifyListeners();

    try {
      await _repository.openFile(path);
      _startPolling();
    } catch (e) {
      _status = FileStatus.error(e.toString());
      notifyListeners();
    }
  }

  void _startPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      final newStatus = await _repository.getFileStatus();
      _status = newStatus;
      notifyListeners();

      _status.maybeWhen(
        complete: () {
          timer.cancel();
          fetchLogs(); // Initial fetch
        },
        error: (_) {
          timer.cancel();
        },
        orElse: () {},
      );
    });
  }

  Future<void> fetchLogs({int limit = 100, int offset = 0}) async {
    // Only fetch if complete
    if (_status is! FileStatus_Complete) return;

    try {
      final result = await _repository.getLogs(
        filterSql: "", // Main window is never filtered
        ftsQuery: "",
        limit: limit,
        offset: offset,
      );
      _logs = result.logs;
      _totalCount = result.totalCount;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching logs: $e");
    }
  }

  void addFilter(FilterCondition condition) {
    _filters.add(condition);
    notifyListeners();
  }

  void removeFilter(FilterCondition condition) {
    _filters.remove(condition);
    notifyListeners();
  }

  void clearFilters() {
    _filters.clear();
    _filterSql = "";
    notifyListeners();
    search(_lastSearchQuery);
  }

  /// Resets all search and filter state
  void resetAll() {
    _filters.clear();
    _filterSql = "";
    _lastSearchQuery = "";
    _searchError = null;
    _searchResults = [];
    _isSearching = false;
    _hasSelection = false;
    notifyListeners();
  }

  Future<void> applyFilters() async {
    if (_filters.isEmpty) {
      _filterSql = "";
    } else {
      _filterSql = _filters
          .map((f) => f.mode.toSql(f.field, f.value))
          .join(" AND ");
    }
    await search(_lastSearchQuery);
  }

  Future<void> setFilter(String filter) async {
    // Legacy/Manual SQL support
    _filterSql = filter;
    await search(_lastSearchQuery);
  }

  void setSelection(bool value) {
    if (_hasSelection != value) {
      _hasSelection = value;
      notifyListeners();
    }
  }

  void toggleLineNumbers() {
    _showLineNumbers = !_showLineNumbers;
    notifyListeners();
  }

  Future<void> reload() async {
    if (_currentFilePath != null) {
      await openLogFile(_currentFilePath!);
    }
  }

  Future<void> search(String query) async {
    _lastSearchQuery = query;
    _searchError = null;

    // If no query and no filter, clear results
    if (query.isEmpty && _filterSql.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final result = await _repository.getLogs(
        filterSql: _filterSql,
        ftsQuery: query,
        limit: 100, // Limit search results for now
        offset: 0,
      );
      _searchResults = result.logs;
    } catch (e) {
      debugPrint("Error searching: $e");
      _searchError = e.toString();
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<String?> getDetail(int id) async {
    return await _repository.getLogDetail(id);
  }

  Future<List<String>> getFieldValues(String field, String search, {int limit = 20, int offset = 0}) {
    return _repository.getFieldValues(field: field, search: search, limit: limit, offset: offset);
  }
}
