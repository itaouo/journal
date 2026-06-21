import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal/services/diary_encryption_service.dart';

void main() {
  final encryptionService = DiaryEncryptionService();

  group('DiaryEncryptionService', () {
    test('encryptString round-trip succeeds', () async {
      const pin = '1234';
      const plaintext = '這是一段上鎖日記內容';
      final salt = encryptionService.generateSalt();
      final key = await encryptionService.deriveKey(pin, salt);

      final payload = await encryptionService.encryptString(
        plaintext,
        key,
        saltBase64: salt,
      );
      final decrypted = await encryptionService.decryptString(payload, key);

      expect(decrypted, plaintext);
      expect(encryptionService.isEncryptedPayload(payload.serialize()), isTrue);
    });

    test('decryptString fails with wrong key', () async {
      const pin = '1234';
      const plaintext = 'secret';
      final salt = encryptionService.generateSalt();
      final key = await encryptionService.deriveKey(pin, salt);
      final wrongKey = await encryptionService.deriveKey('0000', salt);

      final payload = await encryptionService.encryptString(
        plaintext,
        key,
        saltBase64: salt,
      );

      expect(
        () => encryptionService.decryptString(payload, wrongKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('encryptStringWithPin round-trip succeeds', () async {
      const pin = '5678';
      const plaintext = 'PIN 加密測試';
      final salt = encryptionService.generateSalt();

      final serialized = await encryptionService.encryptStringWithPin(
        plaintext,
        pin,
        salt,
      );
      final decrypted =
          await encryptionService.decryptStringWithPin(serialized, pin);

      expect(decrypted, plaintext);
    });

    test('isEncryptedPayload rejects plaintext', () {
      expect(encryptionService.isEncryptedPayload('hello world'), isFalse);
      expect(encryptionService.isEncryptedPayload(''), isFalse);
    });

    test('encryptBytes round-trip succeeds', () async {
      const pin = '1234';
      final salt = encryptionService.generateSalt();
      final key = await encryptionService.deriveKey(pin, salt);
      final bytes = Uint8List.fromList([1, 2, 3, 4, 255]);

      final payload = await encryptionService.encryptBytes(
        bytes,
        key,
        saltBase64: salt,
      );
      final decrypted = await encryptionService.decryptBytes(payload, key);

      expect(decrypted, bytes);
    });
  });
}
