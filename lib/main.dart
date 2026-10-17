import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'storage.dart';
import 'winsnake_widget.dart';
import 'servicios/windows_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageManager.instance.init();
  await windowManager.ensureInitialized();

  final cfg = StorageManager.instance.configuracion;
  final tamano = cfg.tamano;

  const refW = 337.0;
  const refH = 292.0;
  final contW = (refW * tamano + 0.5).ceilToDouble();
  final contH = (refH * tamano + 0.5).ceilToDouble();

  double screenW = 1920, screenH = 1080;
  try {
    screenW = WindowsServices.getScreenWidth().toDouble();
    screenH = WindowsServices.getScreenHeight().toDouble();
  } catch (_) {
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      screenW = display.size.width;
      screenH = display.size.height;
    } catch (_) {}
  }

  final posX = screenW * 0.7 - contW / 2;
  final posY = screenH - 50 - contH;

  final readyCompleter = Completer<void>();
  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      size: Size(contW, contH),
      minimumSize: const Size(60, 60),
      center: false,
      backgroundColor: Colors.transparent,
      skipTaskbar: true,
      alwaysOnTop: true,
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      try {
        await windowManager.setAsFrameless();
        await windowManager.setResizable(false);
        await windowManager.setBounds(Rect.fromLTWH(posX, posY, contW + 1, contH));
        await windowManager.setBounds(Rect.fromLTWH(posX, posY, contW, contH));
        await windowManager.show();
      } finally {
        if (!readyCompleter.isCompleted) readyCompleter.complete();
      }
    },
  );
  await readyCompleter.future;

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const WinSnakeApp());
}

class WinSnakeApp extends StatelessWidget {
  const WinSnakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WinSnake Tools',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF6C63FF),
          surface: Color(0xFF1A1A2E),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF6C63FF)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF6C63FF),
          ),
        ),
      ),
      home: const WinSnakeWidget(),
    );
  }
}
