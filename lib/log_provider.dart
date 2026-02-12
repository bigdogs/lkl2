import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lkl2/constants.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/src/rust/worker.dart';
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

  // Search Results (Bottom Panel)
  List<Log> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  // UI State
  bool _showLineNumbers = true;
  String? _currentFilePath;
  bool _hasSelection = false;

  Timer? _statusTimer;

  // --- File generation (incremented on each open/reload) ---
  int _fileGeneration = 0;

  /// Whether a file has ever been fully loaded in this session.
  bool _hasEverLoaded = false;

  // --- Progressive loading state ---
  DateTime? _openTimestamp;

  /// Current progress 0.0–1.0 while loading, null otherwise.
  double? _loadProgress;

  /// Current loading phase label ("reading" / "indexing"), null when idle.
  String? _loadPhase;

  /// Number of rows loaded so far (valid while loading).
  int _loadedCount = 0;

  /// Whether the loaded file was truncated.
  bool _truncated = false;

  /// User-configurable max file size in bytes.
  /// `null` means unlimited (maps to `0` on Rust side).
  int? _maxFileSizeBytes = kDefaultMaxFileSize;

  // --- Public getters ---

  FileStatus get status => _status;
  List<Log> get logs => _logs;
  int get totalCount => _totalCount;
  List<Log> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;
  bool get showLineNumbers => _showLineNumbers;
  String? get currentFilePath => _currentFilePath;
  bool get hasSelection => _hasSelection;
  double? get loadProgress => _loadProgress;
  String? get loadPhase => _loadPhase;
  int get loadedCount => _loadedCount;
  bool get truncated => _truncated;
  int? get maxFileSizeBytes => _maxFileSizeBytes;
  int get fileGeneration => _fileGeneration;
  bool get hasEverLoaded => _hasEverLoaded;

  /// Whether the file is currently being loaded (progressive).
  bool get isFileLoading => _status is FileStatus_Loading;

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Initialization (load persisted settings)
  // ---------------------------------------------------------------------------

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(kPrefsKeyMaxFileSize);
    if (stored != null) {
      // -1 sentinel → unlimited (null)
      _maxFileSizeBytes = stored == -1 ? null : stored;
    }
  }

  Future<void> setMaxFileSize(int? bytes) async {
    _maxFileSizeBytes = bytes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefsKeyMaxFileSize, bytes ?? -1);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // File open / polling
  // ---------------------------------------------------------------------------

  Future<void> pickAndOpenFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      await openLogFile(result.files.single.path!);
    }
  }

  Future<void> openLogFile(String path) async {
    // Cancel any ongoing polling first
    _statusTimer?.cancel();
    _statusTimer = null;

    // Increment generation to signal UI widgets to reset local state
    _fileGeneration++;

    _status = FileStatus.loading(
      phase: 'reading',
      progress: 0,
      loadedCount: BigInt.zero,
    );
    _logs = [];
    _totalCount = 0;

    // Reset all search/filter state so the UI starts clean
    _filters.clear();
    _filterSql = "";
    _lastSearchQuery = "";
    _searchResults = [];
    _isSearching = false;
    _searchError = null;
    _hasSelection = false;

    _loadProgress = 0;
    _loadPhase = 'reading';
    _loadedCount = 0;
    _truncated = false;
    _openTimestamp = DateTime.now();
    _currentFilePath = path;
    notifyListeners();

    try {
      await _repository.openFile(path, maxFileSize: _maxFileSizeBytes);
      _startPolling();
    } catch (e) {
      _status = FileStatus.error(e.toString());
      _loadProgress = null;
      _loadPhase = null;
      notifyListeners();
    }
  }

  void _startPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(kFastPollInterval, (_) => _pollStatus());
  }

  Future<void> _pollStatus() async {
    final newStatus = await _repository.getFileStatus();
    _status = newStatus;

    final elapsed = DateTime.now().difference(_openTimestamp!);
    final pastThreshold = elapsed >= kLoadingAnimationThreshold;

    // Upgrade poll interval once past the animation threshold.
    if (pastThreshold &&
        _statusTimer != null &&
        _statusTimer!.tick > 0 &&
        _statusTimer!.tick <
            (kLoadingAnimationThreshold.inMilliseconds ~/
                    kFastPollInterval.inMilliseconds) +
                2) {
      _statusTimer?.cancel();
      _statusTimer = Timer.periodic(kSlowPollInterval, (_) => _pollStatus());
    }

    _status.when(
      uninit: () {},
      loading: (phase, progress, loadedCount) {
        final count = loadedCount.toInt();
        final changed =
            _loadPhase != phase ||
            _loadProgress != progress ||
            _loadedCount != count;
        _loadPhase = phase;
        _loadProgress = progress;
        _loadedCount = count;

        // After the animation threshold, show data + trigger searches.
        if (pastThreshold) {
          _refreshDataDuringLoading();
        }

        if (changed) {
          notifyListeners();
        }
      },
      complete: (totalCount, truncated) {
        _hasEverLoaded = true;
        _loadProgress = null;
        _loadPhase = null;
        _loadedCount = totalCount.toInt();
        _truncated = truncated;
        _statusTimer?.cancel();
        _statusTimer = null;
        fetchLogs();
        notifyListeners();
      },
      error: (msg) {
        _loadProgress = null;
        _loadPhase = null;
        _statusTimer?.cancel();
        _statusTimer = null;
        notifyListeners();
      },
    );
  }

  /// Fetch whatever data is available and re-run the active search.
  /// Called silently during loading — no loading spinners shown.
  void _refreshDataDuringLoading() {
    fetchLogs();
    if (_lastSearchQuery.isNotEmpty || _filterSql.isNotEmpty) {
      _silentSearch(_lastSearchQuery);
    }
  }

  // ---------------------------------------------------------------------------
  // Data fetching
  // ---------------------------------------------------------------------------

  Future<void> fetchLogs({int limit = 100, int offset = 0}) async {
    try {
      final result = await _repository.getLogs(
        filterSql: "",
        ftsQuery: "",
        limit: limit,
        offset: offset,
      );
      if (_totalCount != result.totalCount || !listEquals(_logs, result.logs)) {
        _logs = result.logs;
        _totalCount = result.totalCount;
        notifyListeners();
      }
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
      if (!listEquals(_searchResults, result.logs)) {
        _searchResults = result.logs;
      }
    } catch (e) {
      debugPrint("Error searching: $e");
      _searchError = e.toString();
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Silent search used during progressive loading — no isSearching flicker.
  Future<void> _silentSearch(String query) async {
    try {
      final result = await _repository.getLogs(
        filterSql: _filterSql,
        ftsQuery: query,
        limit: 100,
        offset: 0,
      );
      if (!listEquals(_searchResults, result.logs)) {
        _searchResults = result.logs;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error in silent search: $e");
    }
  }

  Future<String?> getDetail(int id) async {
    return await _repository.getLogDetail(id);
  }

  Future<List<String>> getFieldValues(
    String field,
    String search, {
    int limit = 20,
    int offset = 0,
  }) {
    return _repository.getFieldValues(
      field: field,
      search: search,
      limit: limit,
      offset: offset,
    );
  }
}
