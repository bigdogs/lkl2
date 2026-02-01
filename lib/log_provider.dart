import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lkl2/src/rust/file.dart';

class LogProvider extends ChangeNotifier {
  FileStatus _status = const FileStatus.uninit();
  List<Log> _logs = [];
  int _totalCount = 0;

  // Filter/Search
  String _filterSql = "";
  String _ftsQuery = "";

  // Search Results (Bottom Panel)
  List<Log> _searchResults = [];
  bool _isSearching = false;

  Timer? _statusTimer;

  FileStatus get status => _status;
  List<Log> get logs => _logs;
  int get totalCount => _totalCount;
  List<Log> get searchResults => _searchResults;
  bool get isSearching => _isSearching;

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
      await openFile(path: path);
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
      final newStatus = await getFileStatus();
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
      final result = await getLogs(
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

  Future<void> search(String query) async {
    _ftsQuery = query;
    if (query.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final result = await getLogs(
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
    return await getLogDetail(id: id);
  }
}
