import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowsServices {
  static void setAvoidSleep(bool enable) {
    if (enable) {
      SetThreadExecutionState(
          ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
    } else {
      SetThreadExecutionState(ES_CONTINUOUS);
    }
  }

  static void openFolder(String path) {
    try {
      Process.run('explorer.exe', [path]);
    } catch (_) {}
  }

  static void openProgram(String path) {
    try {
      Process.run(path, []);
    } catch (_) {}
  }

  static int getScreenWidth() => GetSystemMetrics(SM_CXSCREEN);
  static int getScreenHeight() => GetSystemMetrics(SM_CYSCREEN);

  static void setAutoStart(bool enable) {
    const runKeyPath = 'Software\\Microsoft\\Windows\\CurrentVersion\\Run';
    const appName = 'WinSnakeTools';

    final phkResult = calloc<IntPtr>();
    final keyPathUtf16 = runKeyPath.toNativeUtf16();
    try {
      final openStatus = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        keyPathUtf16,
        0,
        enable ? KEY_SET_VALUE : KEY_QUERY_VALUE | KEY_SET_VALUE,
        phkResult,
      );

      if (openStatus == ERROR_SUCCESS) {
        final hKey = phkResult.value;

        if (enable) {
          final exePath = Platform.resolvedExecutable;
          final valueName = appName.toNativeUtf16();
          final valueData = exePath.toNativeUtf16();
          try {
            RegSetValueEx(
              hKey,
              valueName,
              0,
              REG_SZ,
              valueData.cast<Uint8>(),
              (exePath.length + 1) * 2,
            );
          } finally {
            free(valueName);
            free(valueData);
          }
        } else {
          final valueName = appName.toNativeUtf16();
          try {
            RegDeleteValue(hKey, valueName);
          } finally {
            free(valueName);
          }
        }

        RegCloseKey(hKey);
      }
    } finally {
      free(keyPathUtf16);
      free(phkResult);
    }
  }

  static bool isAutoStartEnabled() {
    const runKeyPath = 'Software\\Microsoft\\Windows\\CurrentVersion\\Run';
    final phkResult = calloc<IntPtr>();
    final keyPathUtf16 = runKeyPath.toNativeUtf16();
    try {
      final status = RegOpenKeyEx(
        HKEY_CURRENT_USER, keyPathUtf16, 0, KEY_QUERY_VALUE, phkResult,
      );
      if (status != ERROR_SUCCESS) return false;
      final hKey = phkResult.value;
      final valueName = 'WinSnakeTools'.toNativeUtf16();
      try {
        // Check if the value exists by querying it
        final queryStatus = RegQueryValueEx(hKey, valueName, nullptr, nullptr, nullptr, nullptr);
        return queryStatus == ERROR_SUCCESS;
      } finally {
        free(valueName);
        RegCloseKey(hKey);
      }
    } finally {
      free(keyPathUtf16);
      free(phkResult);
    }
  }

  static void cleanup() {
    setAvoidSleep(false);
  }
}
