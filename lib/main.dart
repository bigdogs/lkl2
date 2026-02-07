import 'dart:io';

import 'package:flutter/material.dart' show MaterialScrollBehavior;
import 'package:flutter/widgets.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:macos_ui/macos_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lkl2/src/rust/frb_generated.dart';
import 'package:provider/provider.dart';
import 'package:lkl2/log_provider.dart';
import 'package:lkl2/theme_provider.dart';
import 'package:lkl2/ui/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(
    externalLibrary: Platform.isMacOS || Platform.isIOS
        ? ExternalLibrary.process(iKnowHowToUseIt: true)
        : ExternalLibrary.open(_defaultDylibFileName()),
  );

  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1000, 750),
    minimumSize: Size(800, 600),
    center: true,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

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
      providers: [
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MacosApp(
            theme: MacosThemeData.light(),
            darkTheme: MacosThemeData.dark(),
            themeMode: themeProvider.themeMode,
            // scrollBehavior: Platform.isMacOS
            //     ? const MacosScrollBehavior()
            //     : const MaterialScrollBehavior(),
            scrollBehavior: const MaterialScrollBehavior(),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
