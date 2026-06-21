import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'diary_encryption_service.dart';

abstract class PinStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecurePinStorage implements PinStorage {
  FlutterSecurePinStorage([FlutterSecureStorage? storage])
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

class MemoryPinStorage implements PinStorage {
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

class DiaryLockService {
  static DiaryLockService? _instance;

  factory DiaryLockService() {
    return _instance ??= DiaryLockService._internal();
  }

  @visibleForTesting
  factory DiaryLockService.withStorage(PinStorage storage) {
    return DiaryLockService._internal(storage: storage);
  }

  @visibleForTesting
  static void resetInstanceForTest() {
    _instance = null;
  }

  DiaryLockService._internal({PinStorage? storage})
      : _storage = storage ?? FlutterSecurePinStorage();

  static const _pinHashKey = 'diary_lock_pin_hash';
  static const _pinSaltKey = 'diary_lock_pin_salt';
  static const pinLength = 4;

  final PinStorage _storage;
  final DiaryEncryptionService _encryptionService = DiaryEncryptionService();
  bool _isUnlockedForSession = false;
  String? _sessionPin;

  bool get isUnlockedForSession => _isUnlockedForSession;

  bool get hasSessionPin => _sessionPin != null;

  void markSessionUnlocked() {
    _isUnlockedForSession = true;
  }

  void resetSession() {
    _isUnlockedForSession = false;
    _sessionPin = null;
  }

  String? get sessionPin => _sessionPin;

  static bool isValidPinFormat(String pin) {
    if (pin.length != pinLength) return false;
    return RegExp(r'^\d+$').hasMatch(pin);
  }

  Future<bool> hasPin() async {
    final hash = await _storage.read(_pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    if (!isValidPinFormat(pin)) {
      throw ArgumentError('PIN 必須為 $pinLength 位數字');
    }

    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(_pinSaltKey, salt);
    await _storage.write(_pinHashKey, hash);
    _cacheSessionPin(pin);
  }

  Future<bool> verifyPin(String pin) async {
    if (!isValidPinFormat(pin)) return false;

    final storedHash = await _storage.read(_pinHashKey);
    final salt = await _storage.read(_pinSaltKey);
    if (storedHash == null || salt == null) return false;

    final valid = storedHash == _hashPin(pin, salt);
    if (valid) {
      _cacheSessionPin(pin);
    }
    return valid;
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (!await verifyPin(oldPin)) return false;
    resetSession();
    await setPin(newPin);
    return true;
  }

  Future<SecretKey> deriveEncryptionKey(String pin, String saltBase64) {
    return _encryptionService.deriveKey(pin, saltBase64);
  }

  Future<SecretKey?> deriveEncryptionKeyForPayload(String serializedPayload) async {
    final pin = _sessionPin;
    if (pin == null) return null;
    if (!_encryptionService.isEncryptedPayload(serializedPayload)) {
      return null;
    }

    final payload = EncryptedPayload.deserialize(serializedPayload);
    return deriveEncryptionKey(pin, payload.salt);
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin$salt');
    return sha256.convert(bytes).toString();
  }

  void _cacheSessionPin(String pin) {
    _sessionPin = pin;
    _isUnlockedForSession = true;
  }
}
