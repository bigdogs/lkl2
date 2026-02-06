import 'package:lkl2/src/rust/file.dart' as rust_file;

abstract class ILogRepository {
  Future<void> openFile(String path);
  Future<rust_file.FileStatus> getFileStatus();
  Future<rust_file.Logs> getLogs({
    required String filterSql,
    required String ftsQuery,
    required int limit,
    required int offset,
  });
  Future<String?> getLogDetail(int id);
  Future<List<String>> getFieldValues({
    required String field,
    required String search,
    required int limit,
    required int offset,
  });
}

class LogRepository implements ILogRepository {
  @override
  Future<void> openFile(String path) {
    return rust_file.openFile(path: path);
  }

  @override
  Future<rust_file.FileStatus> getFileStatus() {
    return rust_file.getFileStatus();
  }

  @override
  Future<rust_file.Logs> getLogs({
    required String filterSql,
    required String ftsQuery,
    required int limit,
    required int offset,
  }) {
    return rust_file.getLogs(
      filterSql: filterSql,
      ftsQuery: ftsQuery,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<String?> getLogDetail(int id) {
    return rust_file.getLogDetail(id: id);
  }

  @override
  Future<List<String>> getFieldValues({
    required String field,
    required String search,
    required int limit,
    required int offset,
  }) {
    return rust_file.getFieldValues(
      field: field,
      search: search,
      limit: limit,
      offset: offset,
    );
  }
}
