import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  final BackupSettingsStorage _storage;

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
