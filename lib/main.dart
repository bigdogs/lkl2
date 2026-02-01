import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:lkl2/src/rust/frb_generated.dart';
import 'package:provider/provider.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'log_provider.dart';
import 'package:lkl2/src/rust/file.dart';

Future<void> main() async {
  await RustLib.init(
    externalLibrary: ExternalLibrary.process(iKnowHowToUseIt: true),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => LogProvider())],
      child: MaterialApp(
        title: 'LKL2 Log Viewer',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('LKL2 Log Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () => provider.pickAndOpenFile(),
            tooltip: 'Open File',
          ),
          if (provider.status is FileStatus_Pending)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, LogProvider provider) {
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

class LogViewLayout extends StatefulWidget {
  const LogViewLayout({super.key});

  @override
  State<LogViewLayout> createState() => _LogViewLayoutState();
}

class _LogViewLayoutState extends State<LogViewLayout> {
  late MultiSplitViewController _controller;
  @override
  void initState() {
    super.initState();
    _controller = MultiSplitViewController(
      areas: [
        Area(data: const MainLogArea(), flex: 6),
        Area(data: const BottomArea(), flex: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiSplitView(
      axis: Axis.vertical,
      controller: _controller,
      builder: (context, area) => area.data as Widget,
    );
  }
}

class MainLogArea extends StatelessWidget {
  const MainLogArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Row(
            children: [
              Text("Main Logs", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(child: LogList(logs: provider.logs)),
      ],
    );
  }
}

class BottomArea extends StatelessWidget {
  const BottomArea({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LogProvider>();

    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "SQL Filter (e.g. eventName='Error')",
                    prefixIcon: Icon(Icons.filter_list),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (value) => provider.setFilter(value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search logs (Full Text)...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (value) => provider.search(value),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        // Results
        Expanded(
          child: provider.isSearching
              ? const Center(child: CircularProgressIndicator())
              : LogList(logs: provider.searchResults),
        ),
        if (provider.searchResults.isEmpty && !provider.isSearching)
          Container(
            padding: const EdgeInsets.all(4),
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: const Text("0 match found", style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

class LogList extends StatelessWidget {
  final List<Log> logs;

  const LogList({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text("No logs"));
    }

    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return LogItem(log: log);
      },
    );
  }
}

class LogItem extends StatelessWidget {
  final Log log;

  const LogItem({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final fields = log.fields;
    final time = fields["eventTime"] ?? "";
    final name = fields["eventName"] ?? "";
    final line = fields["lineNumber"] ?? log.id.toString();

    return InkWell(
      onTap: () {
        _showDetail(context, log.id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 50,
              child: Text(
                line,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            SizedBox(
              width: 180,
              child: Text(
                time,
                style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    fields.entries
                        .where(
                          (e) => ![
                            "eventTime",
                            "eventName",
                            "lineNumber",
                          ].contains(e.key),
                        )
                        .map((e) => "${e.key}:${e.value}")
                        .join(" | "),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, int id) async {
    final provider = context.read<LogProvider>();
    final content = await provider.getDetail(id);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Log Detail #$id"),
          content: SingleChildScrollView(
            child: SelectableText(content ?? "No content"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
    }
  }
}
