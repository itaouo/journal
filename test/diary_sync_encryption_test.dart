import 'package:flutter_test/flutter_test.dart';
import 'package:journal/models/diary.dart';
import 'package:journal/models/diary_date.dart';
import 'package:journal/models/picture.dart';
import 'package:journal/services/cloud_diary_codec.dart';
import 'package:journal/services/diary_encryption_service.dart';

void main() {
  final codec = CloudDiaryCodec();
  final encryptionService = DiaryEncryptionService();

  group('CloudDiaryCodec encryption', () {
    test('locked encrypted diary serializes without plaintext content', () async {
      const pin = '1234';
      final diary = Diary(
        id: 'test-id',
        createTime: DateTime(2024, 1, 1),
        updateTime: DateTime(2024, 1, 2),
        date: DiaryDate.fromDateTime(DateTime(2024, 1, 1)),
        content: 'secret content',
        isLocked: true,
        pictures: [
          Picture.fromUrl(
            '',
            caption: 'photo caption',
            driveFileId: 'drive-file-id',
            isEncrypted: true,
          ),
        ],
      );

      final encrypted =
          await encryptionService.encryptDiaryFields(diary, pin);
      final jsonMap = codec.diaryToJsonMap(encrypted);

      expect(jsonMap['encryptionVersion'], 1);
      expect(jsonMap['encryptedContent'], isNotNull);
      expect(jsonMap.containsKey('content'), isFalse);
      expect(jsonMap['isLocked'], isTrue);

      final restored = codec.diaryFromJsonMap(jsonMap);
      expect(restored.isLocked, isTrue);
      expect(
        encryptionService.isEncryptedPayload(restored.content),
        isTrue,
      );
    });

    test('unlocked diary with encryptAllBackups uses encrypted format', () async {
      const pin = '1234';
      final diary = Diary(
        id: 'plain-id',
        createTime: DateTime(2024, 1, 1),
        updateTime: DateTime(2024, 1, 2),
        date: DiaryDate.fromDateTime(DateTime(2024, 1, 1)),
        content: 'hihi',
        isLocked: false,
      );

      final encrypted = await encryptionService.encryptDiaryFields(
        diary,
        pin,
        forCloudBackup: true,
      );
      final jsonMap = codec.diaryToJsonMap(
        encrypted,
        encryptAllBackups: true,
      );

      expect(jsonMap['encryptionVersion'], 1);
      expect(jsonMap['encryptedContent'], isNotNull);
      expect(jsonMap.containsKey('content'), isFalse);
      expect(jsonMap['isLocked'], isFalse);
    });

    test('unlocked diary without encryptAllBackups keeps plaintext format', () {
      final diary = Diary(
        id: 'plain-id',
        createTime: DateTime(2024, 1, 1),
        updateTime: DateTime(2024, 1, 2),
        date: DiaryDate.fromDateTime(DateTime(2024, 1, 1)),
        content: 'plain content',
        isLocked: false,
      );

      final jsonMap = codec.diaryToJsonMap(diary);
      expect(jsonMap['content'], 'plain content');
      expect(jsonMap.containsKey('encryptionVersion'), isFalse);

      final restored = codec.diaryFromJsonMap(jsonMap);
      expect(restored.content, 'plain content');
      expect(restored.isLocked, isFalse);
    });

    test('locked plaintext content throws when serializing for cloud', () {
      final diary = Diary(
        id: 'leak-id',
        createTime: DateTime(2024, 1, 1),
        updateTime: DateTime(2024, 1, 2),
        date: DiaryDate.fromDateTime(DateTime(2024, 1, 1)),
        content: 'leaked plaintext',
        isLocked: true,
      );

      expect(
        () => codec.diaryToJsonMap(diary),
        throwsA(isA<PlaintextCloudUploadException>()),
      );
    });

    test('legacy locked plaintext cloud json remains readable', () {
      final jsonMap = {
        'id': 'legacy-id',
        'createTime': '2024-01-01T00:00:00.000Z',
        'updateTime': '2024-01-02T00:00:00.000Z',
        'isDeleted': false,
        'date': '2024-01-01',
        'content': 'legacy plain locked',
        'isLocked': true,
        'pictures': [],
      };

      final restored = codec.diaryFromJsonMap(jsonMap);
      expect(restored.content, 'legacy plain locked');
      expect(restored.isLocked, isTrue);
      expect(codec.isEncryptedCloudDiary(restored), isFalse);
    });

    test('encrypted unlocked cloud json is detected', () {
      final jsonMap = {
        'id': 'enc-id',
        'createTime': '2024-01-01T00:00:00.000Z',
        'updateTime': '2024-01-02T00:00:00.000Z',
        'isDeleted': false,
        'date': '2024-01-01',
        'isLocked': false,
        'encryptionVersion': 1,
        'encryptedContent': '{"v":1,"salt":"abc","nonce":"def","data":"ghi"}',
        'pictures': [],
      };

      expect(codec.isEncryptedCloudJson(jsonMap), isTrue);
      final restored = codec.diaryFromJsonMap(jsonMap);
      expect(restored.isLocked, isFalse);
      expect(restored.content, jsonMap['encryptedContent']);
    });
  });
}
