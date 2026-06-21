import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/diary.dart';
import '../models/picture.dart';

class EncryptedPayload {
  final int version;
  final String salt;
  final String nonce;
  final String data;

  const EncryptedPayload({
    required this.version,
    required this.salt,
    required this.nonce,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'salt': salt,
        'nonce': nonce,
        'data': data,
      };

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedPayload(
      version: json['v'] as int? ?? 1,
      salt: json['salt'] as String,
      nonce: json['nonce'] as String,
      data: json['data'] as String,
    );
  }

  String serialize() => jsonEncode(toJson());

  factory EncryptedPayload.deserialize(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Invalid encrypted payload');
    }
    return EncryptedPayload.fromJson(decoded);
  }
}

class DiaryEncryptionService {
  static final DiaryEncryptionService _instance =
      DiaryEncryptionService._internal();

  factory DiaryEncryptionService() => _instance;

  DiaryEncryptionService._internal();

  static const payloadVersion = 1;
  static const pbkdf2Iterations = 100000;

  final AesGcm _algorithm = AesGcm.with256bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: pbkdf2Iterations,
    bits: 256,
  );

  bool isEncryptedPayload(String value) {
    if (value.isEmpty) return false;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return false;
      return decoded['v'] == payloadVersion &&
          decoded['salt'] is String &&
          decoded['nonce'] is String &&
          decoded['data'] is String;
    } catch (_) {
      return false;
    }
  }

  String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<SecretKey> deriveKey(String pin, String saltBase64) async {
    final saltBytes = base64Url.decode(saltBase64);
    return _pbkdf2.deriveKeyFromPassword(
      password: pin,
      nonce: saltBytes,
    );
  }

  Future<EncryptedPayload> encryptString(
    String plaintext,
    SecretKey key, {
    String? saltBase64,
  }) async {
    final salt = saltBase64 ?? generateSalt();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );

    return EncryptedPayload(
      version: payloadVersion,
      salt: salt,
      nonce: base64Url.encode(secretBox.nonce),
      data: base64Url.encode(secretBox.cipherText + secretBox.mac.bytes),
    );
  }

  Future<String> decryptString(EncryptedPayload payload, SecretKey key) async {
    final nonce = base64Url.decode(payload.nonce);
    final combined = base64Url.decode(payload.data);
    if (combined.length < 16) {
      throw StateError('Invalid encrypted data');
    }

    final macLength = _algorithm.macAlgorithm.macLength;
    final cipherText = combined.sublist(0, combined.length - macLength);
    final macBytes = combined.sublist(combined.length - macLength);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decrypted = await _algorithm.decrypt(
      secretBox,
      secretKey: key,
    );
    return utf8.decode(decrypted);
  }

  Future<EncryptedPayload> encryptBytes(
    Uint8List plaintext,
    SecretKey key, {
    String? saltBase64,
  }) async {
    final salt = saltBase64 ?? generateSalt();
    final secretBox = await _algorithm.encrypt(
      plaintext,
      secretKey: key,
    );

    return EncryptedPayload(
      version: payloadVersion,
      salt: salt,
      nonce: base64Url.encode(secretBox.nonce),
      data: base64Url.encode(secretBox.cipherText + secretBox.mac.bytes),
    );
  }

  Future<Uint8List> decryptBytes(EncryptedPayload payload, SecretKey key) async {
    final nonce = base64Url.decode(payload.nonce);
    final combined = base64Url.decode(payload.data);
    final macLength = _algorithm.macAlgorithm.macLength;
    final cipherText = combined.sublist(0, combined.length - macLength);
    final macBytes = combined.sublist(combined.length - macLength);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    final decrypted = await _algorithm.decrypt(
      secretBox,
      secretKey: key,
    );
    return Uint8List.fromList(decrypted);
  }

  Future<String> encryptStringWithPin(
    String plaintext,
    String pin,
    String saltBase64,
  ) async {
    final key = await deriveKey(pin, saltBase64);
    final payload = await encryptString(plaintext, key, saltBase64: saltBase64);
    return payload.serialize();
  }

  Future<String> decryptStringWithPin(String serialized, String pin) async {
    final payload = EncryptedPayload.deserialize(serialized);
    final key = await deriveKey(pin, payload.salt);
    return decryptString(payload, key);
  }

  Future<Diary> encryptDiaryFields(
    Diary diary,
    String pin, {
    bool forCloudBackup = false,
  }) async {
    if (!diary.isLocked && !forCloudBackup) return diary;
    if (isEncryptedPayload(diary.content)) return diary;

    var plaintextContent = diary.content;

    final contentSalt = generateSalt();
    final contentKey = await deriveKey(pin, contentSalt);
    final encryptedContent = await encryptString(
      plaintextContent,
      contentKey,
      saltBase64: contentSalt,
    );

    final encryptedPictures = <Picture>[];
    for (final picture in diary.pictures) {
      String? encryptedCaption;
      if (picture.caption != null && picture.caption!.isNotEmpty) {
        var captionText = picture.caption!;
        if (isEncryptedPayload(captionText)) {
          captionText = await decryptStringWithPin(captionText, pin);
        }
        final captionSalt = generateSalt();
        final captionKey = await deriveKey(pin, captionSalt);
        encryptedCaption = (await encryptString(
          captionText,
          captionKey,
          saltBase64: captionSalt,
        )).serialize();
      }

      final shouldMarkEncrypted = forCloudBackup
          ? picture.isLocalFile || picture.driveFileId != null
          : picture.isLocalFile || picture.driveFileId != null;

      encryptedPictures.add(
        Picture(
          pictureUrl: picture.pictureUrl,
          caption: encryptedCaption,
          isLocalFile: picture.isLocalFile,
          driveFileId: picture.driveFileId,
          isEncrypted: shouldMarkEncrypted,
        ),
      );
    }

    return Diary(
      id: diary.id,
      createTime: diary.createTime,
      updateTime: diary.updateTime,
      isDeleted: diary.isDeleted,
      date: diary.date,
      content: encryptedContent.serialize(),
      pictures: encryptedPictures,
      isLocked: diary.isLocked,
    );
  }

  Future<Diary> decryptDiaryFields(Diary diary, String pin) async {
    if (!diary.isLocked && !isEncryptedPayload(diary.content)) return diary;

    var content = diary.content;
    if (isEncryptedPayload(content)) {
      content = await decryptStringWithPin(content, pin);
    }

    final decryptedPictures = <Picture>[];
    for (final picture in diary.pictures) {
      var caption = picture.caption;
      if (caption != null && isEncryptedPayload(caption)) {
        caption = await decryptStringWithPin(caption, pin);
      }

      decryptedPictures.add(
        Picture(
          pictureUrl: picture.pictureUrl,
          caption: caption,
          isLocalFile: picture.isLocalFile,
          driveFileId: picture.driveFileId,
          isEncrypted: picture.isEncrypted,
        ),
      );
    }

    return Diary(
      id: diary.id,
      createTime: diary.createTime,
      updateTime: diary.updateTime,
      isDeleted: diary.isDeleted,
      date: diary.date,
      content: content,
      pictures: decryptedPictures,
      isLocked: diary.isLocked,
    );
  }

  Diary redactLockedDiary(Diary diary) {
    if (!diary.isLocked) return diary;

    return Diary(
      id: diary.id,
      createTime: diary.createTime,
      updateTime: diary.updateTime,
      isDeleted: diary.isDeleted,
      date: diary.date,
      content: '',
      pictures: diary.pictures
          .map(
            (picture) => Picture(
              pictureUrl: picture.pictureUrl,
              caption: null,
              isLocalFile: picture.isLocalFile,
              driveFileId: picture.driveFileId,
              isEncrypted: picture.isEncrypted,
            ),
          )
          .toList(),
      isLocked: true,
    );
  }

  String encryptedFilePath(String originalPath) => '$originalPath.enc';

  bool isEncryptedFilePath(String path) => path.endsWith('.enc');

  Future<Picture> encryptLocalPictureFile(Picture picture, String pin) async {
    if (!picture.isLocalFile || picture.isEncrypted) return picture;

    final sourceFile = File(picture.pictureUrl);
    if (!await sourceFile.exists()) return picture;

    final bytes = await sourceFile.readAsBytes();
    final salt = generateSalt();
    final key = await deriveKey(pin, salt);
    final payload = await encryptBytes(bytes, key, saltBase64: salt);

    final encPath = encryptedFilePath(picture.pictureUrl);
    await File(encPath).writeAsString(payload.serialize());
    await sourceFile.delete();

    return Picture.fromFile(
      encPath,
      caption: picture.caption,
      isEncrypted: true,
    );
  }

  Future<Picture> decryptLocalPictureFile(Picture picture, String pin) async {
    if (!picture.isLocalFile || !picture.isEncrypted) return picture;

    final encFile = File(picture.pictureUrl);
    if (!await encFile.exists()) return picture;

    final payload = EncryptedPayload.deserialize(await encFile.readAsString());
    final key = await deriveKey(pin, payload.salt);
    final bytes = await decryptBytes(payload, key);

    final plainPath = picture.pictureUrl.endsWith('.enc')
        ? picture.pictureUrl.substring(0, picture.pictureUrl.length - 4)
        : picture.pictureUrl;
    await File(plainPath).writeAsBytes(bytes);
    await encFile.delete();

    return Picture.fromFile(
      plainPath,
      caption: picture.caption,
      isEncrypted: false,
    );
  }

  Future<Picture> decryptLocalPictureToTemp(Picture picture, String pin) async {
    if (!picture.isLocalFile || !picture.isEncrypted) return picture;

    final encFile = File(picture.pictureUrl);
    if (!await encFile.exists()) return picture;

    final payload = EncryptedPayload.deserialize(await encFile.readAsString());
    final key = await deriveKey(pin, payload.salt);
    final bytes = await decryptBytes(payload, key);

    final tempDir = Directory.systemTemp;
    final tempPath =
        '${tempDir.path}/journal_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(tempPath).writeAsBytes(bytes);

    return Picture.fromFile(
      tempPath,
      caption: picture.caption,
      isEncrypted: false,
    );
  }
}
