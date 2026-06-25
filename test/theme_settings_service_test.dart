import 'package:flutter_test/flutter_test.dart';
import 'package:journal/services/theme_settings_service.dart';

void main() {
  setUp(() {
    ThemeSettingsService.resetInstanceForTest();
  });

  group('ThemeSettingsService', () {
    test('theme color defaults to purple', () async {
      final service =
          ThemeSettingsService.withStorage(MemoryThemeSettingsStorage());

      await service.load();
      expect(service.themeColor, AppThemeColor.purple);
    });

    test('setThemeColor persists value', () async {
      final storage = MemoryThemeSettingsStorage();
      final service = ThemeSettingsService.withStorage(storage);

      await service.setThemeColor(AppThemeColor.blue);
      expect(service.themeColor, AppThemeColor.blue);

      ThemeSettingsService.resetInstanceForTest();
      final reloaded = ThemeSettingsService.withStorage(storage);
      await reloaded.load();
      expect(reloaded.themeColor, AppThemeColor.blue);
    });

    test('setThemeColor notifies listeners', () async {
      final service =
          ThemeSettingsService.withStorage(MemoryThemeSettingsStorage());
      var notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.setThemeColor(AppThemeColor.green);
      expect(notifyCount, 1);
    });

    test('AppThemeColor labels and seed colors are defined', () {
      for (final color in AppThemeColor.values) {
        expect(color.label, isNotEmpty);
        expect(color.seedColor, isNotNull);
      }
    });
  });
}
