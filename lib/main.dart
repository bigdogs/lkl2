import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lkl2/src/rust/api/simple.dart';
import 'package:lkl2/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Log Viewer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        fontFamily: 'Consolas', // Or generic monospace
      ),
      home: const LogViewerPage(),
    );
  }
}

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  String? _filePath;
  int _totalLines = 0;
  bool _isLoading = false;

  // Cache for lines: index -> content
  final Map<int, String> _lineCache = {};

  // Track pending requests to avoid duplicate fetches
  final Set<int> _pendingPages = {};

  static const int _pageSize = 100;
  final ScrollController _scrollController = ScrollController();

  Future<void> _pickAndOpenFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
          _filePath = result.files.single.path;
          _lineCache.clear();
          _pendingPages.clear();
          _totalLines = 0;
        });

        // Open file in Rust (builds index)
        // This might take a moment for large files
        final lines = await openFile(path: _filePath!);

        if (mounted) {
          setState(() {
            _totalLines = lines.toInt();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPage(int pageIndex) async {
    if (_pendingPages.contains(pageIndex)) return;

    _pendingPages.add(pageIndex);

    try {
      final startLine = pageIndex * _pageSize;
      // Fetch from Rust
      final lines = await readLines(
        startLineIndex: BigInt.from(startLine),
        count: BigInt.from(_pageSize),
      );

      if (mounted) {
        setState(() {
          for (int i = 0; i < lines.length; i++) {
            _lineCache[startLine + i] = lines[i];
          }
          _pendingPages.remove(pageIndex);
        });
      }
    } catch (e) {
      debugPrint("Error fetching page $pageIndex: $e");
      _pendingPages.remove(pageIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _filePath == null
              ? 'Log Viewer'
              : '...${_filePath!.split(RegExp(r'[/\\]')).last}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _isLoading ? null : _pickAndOpenFile,
            tooltip: 'Open File',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Indexing file... Please wait.'),
          ],
        ),
      );
    }

    if (_filePath == null) {
      return const Center(child: Text('Open a log file to start'));
    }

    if (_totalLines == 0) {
      return const Center(child: Text('File is empty'));
    }

    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _totalLines,
        itemBuilder: (context, index) {
          // Check if we have the line
          if (_lineCache.containsKey(index)) {
            return _buildLineItem(index, _lineCache[index]!);
          } else {
            // Trigger fetch for this page
            final pageIndex = index ~/ _pageSize;
            _fetchPage(pageIndex);

            // Also pre-fetch next page for smooth scrolling
            if (index % _pageSize > _pageSize * 0.8) {
              _fetchPage(pageIndex + 1);
            }

            return const SizedBox(
              height: 20,
              child: LinearProgressIndicator(minHeight: 2, color: Colors.grey),
            );
          }
        },
      ),
    );
  }

  Widget _buildLineItem(int index, String content) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
