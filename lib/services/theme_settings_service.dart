import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppThemeColor {
  purple,
  blue,
  green,
  orange,
  teal,
  red,
  pink,
  indigo,
}

extension AppThemeColorX on AppThemeColor {
  MaterialColor get materialColor {
    switch (this) {
      case AppThemeColor.purple:
        return Colors.purple;
      case AppThemeColor.blue:
        return Colors.blue;
      case AppThemeColor.green:
        return Colors.green;
      case AppThemeColor.orange:
        return Colors.orange;
      case AppThemeColor.teal:
        return Colors.teal;
      case AppThemeColor.red:
        return Colors.red;
      case AppThemeColor.pink:
        return Colors.pink;
      case AppThemeColor.indigo:
        return Colors.indigo;
    }
  }

  /// 主題識別色（Material shade500，供非 UI 用途）
  Color get seedColor => materialColor.shade500;

  /// App 鋪底背景色（Material shade50）
  Color get cardBackground => materialColor.shade50;

  Color get sectionHeader => materialColor.shade800;

  Color get accentDark => materialColor.shade900;

  String get label {
    switch (this) {
      case AppThemeColor.purple:
        return '紫色';
      case AppThemeColor.blue:
        return '藍色';
      case AppThemeColor.green:
        return '綠色';
      case AppThemeColor.orange:
        return '橙色';
      case AppThemeColor.teal:
        return '青色';
      case AppThemeColor.red:
        return '紅色';
      case AppThemeColor.pink:
        return '粉色';
      case AppThemeColor.indigo:
        return '靛色';
    }
  }
}

AppThemeColor appThemeColorFromStorage(String? value) {
  if (value == null) return AppThemeColor.purple;
  for (final color in AppThemeColor.values) {
    if (color.name == value) return color;
  }
  return AppThemeColor.purple;
}

abstract class ThemeSettingsStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureThemeSettingsStorage implements ThemeSettingsStorage {
  FlutterSecureThemeSettingsStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryThemeSettingsStorage implements ThemeSettingsStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

class ThemeSettingsService extends ChangeNotifier {
  static ThemeSettingsService? _instance;

  factory ThemeSettingsService() {
    return _instance ??= ThemeSettingsService._internal();
  }

  @visibleForTesting
  factory ThemeSettingsService.withStorage(ThemeSettingsStorage storage) {
    return ThemeSettingsService._internal(storage: storage);
  }

  @visibleForTesting
  static void resetInstanceForTest() {
    _instance = null;
  }

  ThemeSettingsService._internal({ThemeSettingsStorage? storage})
      : _storage = storage ?? FlutterSecureThemeSettingsStorage();

  static const _themeColorKey = 'app_theme_color';

  final ThemeSettingsStorage _storage;
  AppThemeColor _themeColor = AppThemeColor.purple;

  AppThemeColor get themeColor => _themeColor;

  Future<void> load() async {
    final value = await _storage.read(_themeColorKey);
    _themeColor = appThemeColorFromStorage(value);
    notifyListeners();
  }

  Future<void> setThemeColor(AppThemeColor color) async {
    if (_themeColor == color) return;
    _themeColor = color;
    await _storage.write(_themeColorKey, color.name);
    notifyListeners();
  }
}
