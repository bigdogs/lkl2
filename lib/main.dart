import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:lkl2/src/rust/frb_generated.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/ui/pages/home_page.dart';

Future<void> main() async {
  await RustLib.init(
    externalLibrary: ExternalLibrary.open(_defaultDylibFileName()),
  );
  runApp(const Lkl2());
}

String _defaultDylibFileName() {
  if (Platform.isWindows) {
    return 'liblkl2.dll';
  }
  if (Platform.isMacOS) {
    return 'libliblkl2.dylib';
  }
  if (Platform.isLinux) {
    return 'libliblkl2.so';
  }
  return 'liblkl2';
}

class Lkl2 extends StatelessWidget {
  const Lkl2({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => LogProvider())],
      child: MacosApp(
        theme: MacosThemeData.light(),
        darkTheme: MacosThemeData.dark(),
        home: const HomePage(),
      ),
    );
  }
}
