import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:lkl2/src/rust/frb_generated.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/pages/home_page.dart';

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
