import '../models/diary.dart';
import '../models/diary_date.dart';
import '../models/picture.dart';
import 'diary_encryption_service.dart';

class PlaintextCloudUploadException implements Exception {
  final String message;

  PlaintextCloudUploadException([
    this.message = '需加密的日記不能以明文上傳至雲端',
  ]);

  @override
  String toString() => message;
}

class CloudDiaryCodec {
  static const encryptionVersion = 1;

  final DiaryEncryptionService _encryptionService = DiaryEncryptionService();

  bool shouldEncryptForCloud(Diary diary, bool encryptAllBackups) {
    return diary.isLocked || encryptAllBackups;
  }

  bool isEncryptedCloudDiary(Diary diary) {
    return _encryptionService.isEncryptedPayload(diary.content);
  }

  bool isEncryptedCloudJson(Map<String, dynamic> data) {
    return data['encryptionVersion'] == encryptionVersion &&
        data['encryptedContent'] != null;
  }

  Map<String, dynamic> diaryToJsonMap(
    Diary diary, {
    bool encryptAllBackups = false,
  }) {
    if (shouldEncryptForCloud(diary, encryptAllBackups)) {
      if (!_encryptionService.isEncryptedPayload(diary.content)) {
        throw PlaintextCloudUploadException();
      }

      return {
        'id': diary.id,
        'createTime': diary.createTime.toUtc().toIso8601String(),
        'updateTime': diary.updateTime.toUtc().toIso8601String(),
        'isDeleted': diary.isDeleted,
        'date': diary.date.toDateString(),
        'isLocked': diary.isLocked,
        'encryptionVersion': encryptionVersion,
        'encryptedContent': diary.content,
        'pictures': diary.pictures
            .map((picture) => {
                  if (picture.driveFileId != null)
                    'driveFileId': picture.driveFileId,
                  if (picture.caption != null)
                    'encryptedCaption': picture.caption,
                  'isEncrypted': picture.isEncrypted,
                })
            .toList(),
      };
    }

    return {
      'id': diary.id,
      'createTime': diary.createTime.toUtc().toIso8601String(),
      'updateTime': diary.updateTime.toUtc().toIso8601String(),
      'isDeleted': diary.isDeleted,
      'date': diary.date.toDateString(),
      'content': diary.content,
      'isLocked': diary.isLocked,
      'pictures': diary.pictures
          .map((picture) => {
                'pictureUrl': picture.pictureUrl,
                'caption': picture.caption,
                'driveFileId': picture.driveFileId,
              })
          .toList(),
    };
  }

  Diary diaryFromJsonMap(Map<String, dynamic> data) {
    final picturesData = data['pictures'] as List<dynamic>? ?? [];
    final isLocked = data['isLocked'] as bool? ?? false;
    final encrypted = isEncryptedCloudJson(data);
    final content = encrypted
        ? data['encryptedContent'] as String? ?? ''
        : data['content'] as String? ?? '';

    return Diary(
      id: data['id'] as String,
      createTime: DateTime.parse(data['createTime'] as String).toLocal(),
      updateTime: DateTime.parse(data['updateTime'] as String).toLocal(),
      isDeleted: data['isDeleted'] as bool? ?? false,
      date: DiaryDate.fromString(data['date'] as String),
      content: content,
      isLocked: isLocked,
      pictures: picturesData
          .map((item) {
            final map = item as Map<String, dynamic>;
            final driveFileId = map['driveFileId'] as String?;
            final isPictureEncrypted = map['isEncrypted'] as bool? ?? false;
            final caption = encrypted
                ? map['encryptedCaption'] as String?
                : map['caption'] as String?;
            final pictureUrl = encrypted
                ? ''
                : map['pictureUrl'] as String? ??
                    (driveFileId != null
                        ? Picture.driveThumbnailUrl(driveFileId)
                        : '');
            return Picture.fromUrl(
              pictureUrl,
              caption: caption,
              driveFileId: driveFileId,
              isEncrypted: isPictureEncrypted,
            );
          })
          .toList(),
    );
  }
}
