import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum LockPinPromptMode {
  perLockedDiary,
  oncePerAppSession,
}

String lockPinPromptModeLabel(LockPinPromptMode mode) {
  switch (mode) {
    case LockPinPromptMode.perLockedDiary:
      return '每次開啟都輸入 PIN';
    case LockPinPromptMode.oncePerAppSession:
      return '本次 App 解鎖一次即可';
  }
}

abstract class BackupSettingsStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureBackupSettingsStorage implements BackupSettingsStorage {
  FlutterSecureBackupSettingsStorage([FlutterSecureStorage? storage])
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

class MemoryBackupSettingsStorage implements BackupSettingsStorage {
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

class BackupSettingsService {
  static BackupSettingsService? _instance;

  factory BackupSettingsService() {
    return _instance ??= BackupSettingsService._internal();
  }

  @visibleForTesting
  factory BackupSettingsService.withStorage(BackupSettingsStorage storage) {
    return BackupSettingsService._internal(storage: storage);
  }

  @visibleForTesting
  static void resetInstanceForTest() {
    _instance = null;
  }

  BackupSettingsService._internal({BackupSettingsStorage? storage})
      : _storage = storage ?? FlutterSecureBackupSettingsStorage();

  static const _encryptAllBackupsKey = 'encrypt_all_backups';
  static const _lastSyncAtKey = 'last_sync_at';
  static const _lastRestoreAtKey = 'last_restore_at';
  static const _lockPinPromptModeKey = 'lock_pin_prompt_mode';
  static const _perLockedDiaryValue = 'per_locked_diary';
  static const _oncePerAppSessionValue = 'once_per_app_session';

  final BackupSettingsStorage _storage;

  Future<DateTime?> _readDateTime(String key) async {
    final value = await _storage.read(key);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _writeDateTime(String key, DateTime time) async {
    await _storage.write(key, time.toIso8601String());
  }

  Future<DateTime?> getLastSyncAt() => _readDateTime(_lastSyncAtKey);

  Future<void> setLastSyncAt(DateTime time) =>
      _writeDateTime(_lastSyncAtKey, time);

  Future<DateTime?> getLastRestoreAt() => _readDateTime(_lastRestoreAtKey);

  Future<void> setLastRestoreAt(DateTime time) =>
      _writeDateTime(_lastRestoreAtKey, time);

  Future<LockPinPromptMode> getLockPinPromptMode() async {
    final value = await _storage.read(_lockPinPromptModeKey);
    if (value == _oncePerAppSessionValue) {
      return LockPinPromptMode.oncePerAppSession;
    }
    return LockPinPromptMode.perLockedDiary;
  }

  Future<void> setLockPinPromptMode(LockPinPromptMode mode) async {
    await _storage.write(
      _lockPinPromptModeKey,
      mode == LockPinPromptMode.oncePerAppSession
          ? _oncePerAppSessionValue
          : _perLockedDiaryValue,
    );
  }

  Future<bool> getEncryptAllBackups() async {
    final value = await _storage.read(_encryptAllBackupsKey);
    return value == 'true';
  }

  Future<void> setEncryptAllBackups(bool enabled) async {
    await _storage.write(
      _encryptAllBackupsKey,
      enabled ? 'true' : 'false',
    );
  }
}
