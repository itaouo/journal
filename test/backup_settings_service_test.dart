import 'package:flutter_test/flutter_test.dart';
import 'package:journal/services/backup_settings_service.dart';

void main() {
  setUp(() {
    BackupSettingsService.resetInstanceForTest();
  });

  group('BackupSettingsService', () {
    test('encrypt all backups defaults to false', () async {
      final service =
          BackupSettingsService.withStorage(MemoryBackupSettingsStorage());
      expect(await service.getEncryptAllBackups(), isFalse);
    });

    test('setEncryptAllBackups persists value', () async {
      final service =
          BackupSettingsService.withStorage(MemoryBackupSettingsStorage());

      await service.setEncryptAllBackups(true);
      expect(await service.getEncryptAllBackups(), isTrue);

      await service.setEncryptAllBackups(false);
      expect(await service.getEncryptAllBackups(), isFalse);
    });
  });
}
