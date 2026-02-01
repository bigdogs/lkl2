import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lkl2/src/rust/file.dart';
import 'package:lkl2/data/repository/log_repository.dart';

class LogProvider extends ChangeNotifier {
  final ILogRepository _repository;

  LogProvider({ILogRepository? repository})
    : _repository = repository ?? LogRepository();

  FileStatus _status = const FileStatus.uninit();
  List<Log> _logs = [];
  int _totalCount = 0;

  // Filter/Search
  String _filterSql = "";
  // String _ftsQuery = "";

  // Search Results (Bottom Panel)
  List<Log> _searchResults = [];
  bool _isSearching = false;

  // UI State
  bool _showLineNumbers = true;
  String? _currentFilePath;

  Timer? _statusTimer;

  FileStatus get status => _status;
  List<Log> get logs => _logs;
  int get totalCount => _totalCount;
  List<Log> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get showLineNumbers => _showLineNumbers;
  String? get currentFilePath => _currentFilePath;

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
        filterSql: _filterSql,
        ftsQuery: "",
        limit: limit,
        offset: offset,
      );
      _logs = result.logs;
      _totalCount = result.totalCount;
      notifyListeners();
    } catch (e) {
      print("Error fetching logs: $e");
    }
  }

  Future<void> setFilter(String filter) async {
    _filterSql = filter;
    await fetchLogs();
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
    // _ftsQuery = query;
    if (query.isEmpty) {
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
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<String?> getDetail(int id) async {
    return await _repository.getLogDetail(id);
  }
}
