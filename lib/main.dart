import 'package:flutter/material.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/night_one_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var bool = UniversalPlatform.isMacOS || UniversalPlatform.isWindows || UniversalPlatform.isLinux;
  if (bool) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(560, 720),
      center: true,
      skipTaskbar: true,
      title: 'Flutter',
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const NightOnePage(),
    );
  }
}
