import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'storage.dart';
import 'bichito_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageManager.instance.init();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(290, 170),
    minimumSize: Size(290, 170),
    center: false,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setResizable(false);
    await windowManager.show();
  });

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const BichitoApp());
}

class BichitoApp extends StatelessWidget {
  const BichitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bichito Widget',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const BichitoWidget(),
    );
  }
}
