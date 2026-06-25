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

    test('last sync and restore timestamps default to null', () async {
      final service =
          BackupSettingsService.withStorage(MemoryBackupSettingsStorage());

      expect(await service.getLastSyncAt(), isNull);
      expect(await service.getLastRestoreAt(), isNull);
    });

    test('last sync and restore timestamps persist value', () async {
      final service =
          BackupSettingsService.withStorage(MemoryBackupSettingsStorage());
      final syncTime = DateTime(2026, 6, 26, 15, 2);
      final restoreTime = DateTime(2026, 6, 26, 14, 30);

      await service.setLastSyncAt(syncTime);
      await service.setLastRestoreAt(restoreTime);

      expect(await service.getLastSyncAt(), syncTime);
      expect(await service.getLastRestoreAt(), restoreTime);
    });

    test('lock pin prompt mode defaults to perLockedDiary', () async {
      final service =
          BackupSettingsService.withStorage(MemoryBackupSettingsStorage());

      expect(
        await service.getLockPinPromptMode(),
        LockPinPromptMode.perLockedDiary,
      );
    });

    test('lock pin prompt mode persists value', () async {
      final service =
          BackupSettingsService.withStorage(MemoryBackupSettingsStorage());

      await service.setLockPinPromptMode(
        LockPinPromptMode.oncePerAppSession,
      );
      expect(
        await service.getLockPinPromptMode(),
        LockPinPromptMode.oncePerAppSession,
      );

      await service.setLockPinPromptMode(LockPinPromptMode.perLockedDiary);
      expect(
        await service.getLockPinPromptMode(),
        LockPinPromptMode.perLockedDiary,
      );
    });
  });
}
