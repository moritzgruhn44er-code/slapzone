import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'ui/theme/app_theme.dart';
import 'lobby/lobby_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fullscreen Landscape + Portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  await Hive.initFlutter();
  await Hive.openBox('stats');
  await Hive.openBox('settings');

  runApp(const ProviderScope(child: SlapZoneApp()));
}

class SlapZoneApp extends StatelessWidget {
  const SlapZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SlapZone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const LobbyScreen(),
    );
  }
}
