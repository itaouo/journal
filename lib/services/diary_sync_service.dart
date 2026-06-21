import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/database_helper.dart';
import '../models/diary.dart';
import '../models/picture.dart';
import 'auth_service.dart';
import 'backup_settings_service.dart';
import 'cloud_diary_codec.dart';
import 'diary_encryption_service.dart';
import 'diary_lock_service.dart';
import 'google_drive_service.dart';

class PinRequiredException implements Exception {
  final String message;

  PinRequiredException([this.message = '需要 PIN 才能處理上鎖日記']);

  @override
  String toString() => message;
}

class PendingDeletePayload {
  final String? driveJsonFileId;
  final List<String> driveFileIds;

  const PendingDeletePayload({
    this.driveJsonFileId,
    this.driveFileIds = const [],
  });
}

class RestoreFromCloudResult {
  final int restoredCount;
  final int skippedCount;

  const RestoreFromCloudResult({
    required this.restoredCount,
    required this.skippedCount,
  });
}

class DiarySyncService {
  static final DiarySyncService _instance = DiarySyncService._internal();

  factory DiarySyncService() => _instance;

  DiarySyncService._internal() {
    _connectivity.onConnectivityChanged.listen((_) {
      syncAllPending();
    });
  }

  final AuthService _authService = AuthService();
  final GoogleDriveService _driveService = GoogleDriveService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final Connectivity _connectivity = Connectivity();
  final DiaryLockService _lockService = DiaryLockService();
  final DiaryEncryptionService _encryptionService = DiaryEncryptionService();
  final BackupSettingsService _backupSettings = BackupSettingsService();
  final CloudDiaryCodec _cloudCodec = CloudDiaryCodec();

  final Set<String> _syncInProgress = {};

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<bool> needsPinForSync() async {
    if (_lockService.hasSessionPin) return false;
    if (await _databaseHelper.hasPendingLockedSync()) return true;
    if (await _backupSettings.getEncryptAllBackups()) {
      return await _databaseHelper.getPendingSyncCount() > 0;
    }
    return false;
  }

  Future<bool> shouldPromptPinBeforeRestore() async {
    if (!await _lockService.hasPin()) return false;
    if (_lockService.hasSessionPin) return false;
    if (await _databaseHelper.hasLockedDiaries()) return true;
    return await _backupSettings.getEncryptAllBackups();
  }

  Future<bool> getEncryptAllBackups() =>
      _backupSettings.getEncryptAllBackups();

  Future<void> setEncryptAllBackups(bool enabled) async {
    await _backupSettings.setEncryptAllBackups(enabled);
    await _databaseHelper.markAllDiariesPendingSync();
  }

  Future<List<Diary>> getDiaries() async {
    final rawDiaries = await _databaseHelper.getAllDiaries();
    final diaries = <Diary>[];
    for (final diary in rawDiaries) {
      diaries.add(await _prepareDiaryForDisplay(diary));
    }
    return diaries;
  }

  Future<Diary?> getDiaryById(String id) async {
    final raw = await _databaseHelper.getDiary(id);
    if (raw == null) return null;
    return _prepareDiaryForDisplay(raw);
  }

  Future<Diary?> getDiaryRaw(String id) async {
    return _databaseHelper.getDiary(id);
  }

  Future<int> getPendingSyncCount() async {
    return _databaseHelper.getPendingSyncCount();
  }

  Future<void> saveDiary(
    Diary diary, {
    List<String> removedDriveFileIds = const [],
  }) async {
    final existing = await _databaseHelper.getDiary(diary.id);
    final existingMeta = await _databaseHelper.getDiarySyncMetadata(diary.id);
    final pendingDeletes = <String>[
      ...?existingMeta?.pendingDriveDeletes,
      ...removedDriveFileIds,
    ];

    final storedDiary = await _prepareDiaryForStorage(
      diary,
      existing: existing,
    );

    if (existing != null) {
      await _databaseHelper.updateDiary(
        storedDiary,
        syncStatus: DiarySyncMetadata.statusPending,
        pendingDriveDeletes: pendingDeletes,
      );
    } else {
      await _databaseHelper.insertDiary(
        storedDiary,
        syncStatus: DiarySyncMetadata.statusPending,
        pendingDriveDeletes: pendingDeletes,
      );
    }

    _scheduleBackgroundSync(diary.id);
  }

  Future<void> setDiaryLocked(String id, bool isLocked) async {
    final existing = await _databaseHelper.getDiary(id);
    if (existing == null) return;

    final pin = _lockService.sessionPin;
    if (pin == null) {
      throw PinRequiredException();
    }

    Diary updated;
    if (isLocked) {
      final plaintext = await _decryptDiaryIfNeeded(existing, pin);
      updated = await _encryptionService.encryptDiaryFields(
        plaintext.copyWith(isLocked: true),
        pin,
      );
      updated = await _encryptLocalPictures(updated, pin);
    } else {
      final decrypted = await _decryptDiaryIfNeeded(existing, pin);
      updated = await _decryptLocalPictures(decrypted, pin);
      updated = await _materializeCloudPictures(updated, pin);
      updated = updated.copyWith(isLocked: false);
    }

    await _databaseHelper.updateDiary(
      updated,
      syncStatus: DiarySyncMetadata.statusPending,
    );
    _scheduleBackgroundSync(id);
  }

  Future<void> reencryptAllLockedDiaries(String oldPin, String newPin) async {
    final lockedIds = await _databaseHelper.getLockedDiaryIds();
    for (final id in lockedIds) {
      final raw = await _databaseHelper.getDiary(id);
      if (raw == null) continue;

      final decrypted = await _encryptionService.decryptDiaryFields(raw, oldPin);
      final withPlainImages = await _decryptLocalPictures(decrypted, oldPin);
      final reencrypted =
          await _encryptionService.encryptDiaryFields(withPlainImages, newPin);
      final stored =
          await _encryptLocalPictures(reencrypted, newPin);

      await _databaseHelper.updateDiary(
        stored,
        syncStatus: DiarySyncMetadata.statusPending,
      );
    }
  }

  Future<void> migratePlaintextLockedDiaries() async {
    final pin = _lockService.sessionPin;
    if (pin == null) return;

    final lockedIds = await _databaseHelper.getLockedDiaryIds();
    for (final id in lockedIds) {
      final raw = await _databaseHelper.getDiary(id);
      if (raw == null || !raw.isLocked) continue;
      if (_encryptionService.isEncryptedPayload(raw.content)) continue;

      final encrypted =
          await _encryptionService.encryptDiaryFields(raw, pin);
      final stored = await _encryptLocalPictures(encrypted, pin);
      await _databaseHelper.updateDiary(
        stored,
        syncStatus: DiarySyncMetadata.statusPending,
      );
    }
  }

  Future<void> deleteDiary(Diary diary) async {
    final meta = await _databaseHelper.getDiarySyncMetadata(diary.id);
    final payload = PendingDeletePayload(
      driveJsonFileId: meta?.driveJsonFileId,
      driveFileIds: diary.pictures
          .map((picture) => picture.driveFileId)
          .whereType<String>()
          .toList(),
    );

    await _databaseHelper.deleteDiary(diary.id);
    _scheduleBackgroundDelete(payload);
  }

  void _scheduleBackgroundSync(String diaryId) {
    Future<void>(() async {
      await _syncDiaryToDrive(diaryId);
    });
  }

  void _scheduleBackgroundDelete(PendingDeletePayload payload) {
    Future<void>(() async {
      await _deleteFromDrive(payload);
    });
  }

  Future<void> syncAllPending() async {
    if (!await _canSyncToDrive()) return;
    await migratePlaintextLockedDiaries();

    final pendingIds = await _databaseHelper.getPendingSyncDiaryIds();
    for (final diaryId in pendingIds) {
      await _syncDiaryToDrive(diaryId);
    }
  }

  Future<RestoreFromCloudResult> restoreFromCloud() async {
    if (!_authService.isSignedIn) {
      throw Exception('請先登入 Google 帳號');
    }
    if (!await isOnline) {
      throw Exception('目前離線，無法從 Google Drive 還原');
    }

    final driveFiles = await _driveService.listAllDiaryJsonFiles();
    var restoredCount = 0;
    var skippedCount = 0;

    for (final driveFile in driveFiles) {
      final cloudDiary =
          await _driveService.downloadDiaryJson(driveFile.fileId);
      if (cloudDiary.isDeleted) {
        skippedCount++;
        continue;
      }

      final localDiary = await _databaseHelper.getDiary(cloudDiary.id);
      if (localDiary == null ||
          cloudDiary.updateTime.isAfter(localDiary.updateTime)) {
        final storedDiary = await _prepareCloudDiaryForStorage(cloudDiary);
        await _databaseHelper.upsertDiaryFromCloud(
          storedDiary,
          driveJsonFileId: driveFile.fileId,
        );
        restoredCount++;
      } else {
        skippedCount++;
      }
    }

    await migratePlaintextLockedDiaries();
    return RestoreFromCloudResult(
      restoredCount: restoredCount,
      skippedCount: skippedCount,
    );
  }

  Future<bool> _canSyncToDrive() async {
    return _authService.isSignedIn && await isOnline;
  }

  Future<void> _syncDiaryToDrive(String diaryId) async {
    if (_syncInProgress.contains(diaryId)) return;
    if (!await _canSyncToDrive()) return;

    _syncInProgress.add(diaryId);
    try {
      var diary = await _databaseHelper.getDiary(diaryId);
      if (diary == null) return;

      final encryptAllBackups = await _backupSettings.getEncryptAllBackups();
      final needsEncryption =
          _cloudCodec.shouldEncryptForCloud(diary, encryptAllBackups);

      if (needsEncryption && !_lockService.hasSessionPin) {
        return;
      }

      final pin = _lockService.sessionPin;

      if (diary.isLocked) {
        await migratePlaintextLockedDiaries();
        diary = await _databaseHelper.getDiary(diaryId);
        if (diary == null) return;
      }

      if (needsEncryption && pin != null) {
        diary = await _ensureEncryptedForSync(diary, pin, encryptAllBackups);
        if (!_encryptionService.isEncryptedPayload(diary.content)) {
          return;
        }
      }

      final meta = await _databaseHelper.getDiarySyncMetadata(diaryId);
      if (meta == null) return;

      final pendingDeletes = [...meta.pendingDriveDeletes];
      for (final fileId in pendingDeletes) {
        try {
          await _driveService.deleteFile(fileId);
        } catch (_) {}
      }

      final localDiary = await _databaseHelper.getDiary(diaryId);
      if (localDiary == null) return;

      final cloudContentDiary = needsEncryption
          ? diary
          : await _preparePlaintextCloudDiary(localDiary, pin);

      final uploadedPictures = await _uploadPicturesForSync(
        localDiary: localDiary,
        cloudDiary: cloudContentDiary,
        needsEncryption: needsEncryption,
        pin: pin,
      );

      final cloudDiary = Diary(
        id: localDiary.id,
        createTime: localDiary.createTime,
        updateTime: localDiary.updateTime,
        isDeleted: localDiary.isDeleted,
        date: localDiary.date,
        content: cloudContentDiary.content,
        pictures: uploadedPictures,
        isLocked: localDiary.isLocked,
      );

      final driveJsonFileId = meta.driveJsonFileId == null
          ? await _driveService.uploadDiaryJson(
              cloudDiary,
              encryptAllBackups: encryptAllBackups,
            )
          : await _driveService.updateDiaryJson(
              cloudDiary,
              meta.driveJsonFileId!,
              encryptAllBackups: encryptAllBackups,
            );

      await _databaseHelper.updateDiary(
        Diary(
          id: localDiary.id,
          createTime: localDiary.createTime,
          updateTime: localDiary.updateTime,
          isDeleted: localDiary.isDeleted,
          date: localDiary.date,
          content: localDiary.content,
          pictures: await _mergePicturesAfterSync(
            localDiary.pictures,
            uploadedPictures,
          ),
          isLocked: localDiary.isLocked,
        ),
        syncStatus: DiarySyncMetadata.statusSynced,
        driveJsonFileId: driveJsonFileId,
        pendingDriveDeletes: const [],
      );
    } on PlaintextCloudUploadException {
      await _databaseHelper.updateSyncStatus(
        diaryId,
        syncStatus: DiarySyncMetadata.statusFailed,
      );
    } catch (_) {
      await _databaseHelper.updateSyncStatus(
        diaryId,
        syncStatus: DiarySyncMetadata.statusFailed,
      );
    } finally {
      _syncInProgress.remove(diaryId);
    }
  }

  Future<void> _deleteFromDrive(PendingDeletePayload payload) async {
    if (!await _canSyncToDrive()) return;

    for (final fileId in payload.driveFileIds) {
      try {
        await _driveService.deleteFile(fileId);
      } catch (_) {}
    }

    final jsonFileId = payload.driveJsonFileId;
    if (jsonFileId != null) {
      try {
        await _driveService.deleteDiaryJson(jsonFileId);
      } catch (_) {}
    }
  }

  Future<Diary> _preparePlaintextCloudDiary(Diary diary, String? pin) async {
    if (pin == null ||
        !_encryptionService.isEncryptedPayload(diary.content)) {
      return diary;
    }

    return _encryptionService.decryptDiaryFields(diary, pin);
  }

  Future<Diary> _ensureEncryptedForSync(
    Diary diary,
    String pin,
    bool encryptAllBackups,
  ) async {
    if (diary.isLocked &&
        !_encryptionService.isEncryptedPayload(diary.content)) {
      final encrypted =
          await _encryptionService.encryptDiaryFields(diary, pin);
      final stored = await _encryptLocalPictures(encrypted, pin);
      await _databaseHelper.updateDiary(
        stored,
        syncStatus: DiarySyncMetadata.statusPending,
      );
      return stored;
    }

    if (encryptAllBackups && !diary.isLocked) {
      return _encryptionService.encryptDiaryFields(
        diary,
        pin,
        forCloudBackup: true,
      );
    }

    return diary;
  }

  Future<List<Picture>> _uploadPicturesForSync({
    required Diary localDiary,
    required Diary cloudDiary,
    required bool needsEncryption,
    required String? pin,
  }) async {
    final uploadedPictures = <Picture>[];
    final pendingOldDriveIds = <String>[];

    for (var i = 0; i < localDiary.pictures.length; i++) {
      final localPicture = localDiary.pictures[i];
      final cloudPicture =
          i < cloudDiary.pictures.length ? cloudDiary.pictures[i] : localPicture;

      if (localPicture.isLocalFile) {
        final file = File(localPicture.pictureUrl);
        if (!await file.exists()) {
          uploadedPictures.add(localPicture);
          continue;
        }

        if (needsEncryption && pin != null) {
          final List<int> bytes;
          if (localDiary.isLocked && localPicture.isEncrypted) {
            bytes = utf8.encode(await file.readAsString());
          } else {
            final rawBytes = await file.readAsBytes();
            final payload = await _encryptionService.encryptBytes(
              rawBytes,
              await _encryptionService.deriveKey(
                pin,
                _encryptionService.generateSalt(),
              ),
            );
            bytes = utf8.encode(payload.serialize());
          }
          final uploaded = await _driveService.uploadEncryptedImage(
            bytes,
            '${localDiary.id}_${DateTime.now().millisecondsSinceEpoch}_$i.enc',
          );
          if (localPicture.driveFileId != null) {
            pendingOldDriveIds.add(localPicture.driveFileId!);
          }
          uploadedPictures.add(
            Picture.fromUrl(
              '',
              caption: cloudPicture.caption,
              driveFileId: uploaded.fileId,
              isEncrypted: true,
            ),
          );
        } else {
          final uploaded = await _driveService.uploadImage(
            file,
            '${localDiary.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          );
          if (localPicture.driveFileId != null &&
              localPicture.driveFileId != uploaded.fileId) {
            pendingOldDriveIds.add(localPicture.driveFileId!);
          }
          uploadedPictures.add(
            Picture.fromUrl(
              uploaded.pictureUrl,
              caption: localPicture.caption,
              driveFileId: uploaded.fileId,
            ),
          );
        }
      } else if (needsEncryption &&
          pin != null &&
          localPicture.driveFileId != null &&
          !localPicture.isEncrypted) {
        try {
          final rawBytes =
              await _driveService.downloadImageBytes(localPicture.driveFileId!);
          final payload = await _encryptionService.encryptBytes(
            rawBytes is Uint8List
                ? rawBytes
                : Uint8List.fromList(rawBytes),
            await _encryptionService.deriveKey(
              pin,
              _encryptionService.generateSalt(),
            ),
          );
          final uploaded = await _driveService.uploadEncryptedImage(
            utf8.encode(payload.serialize()),
            '${localDiary.id}_${DateTime.now().millisecondsSinceEpoch}_$i.enc',
          );
          pendingOldDriveIds.add(localPicture.driveFileId!);
          uploadedPictures.add(
            Picture.fromUrl(
              '',
              caption: cloudPicture.caption,
              driveFileId: uploaded.fileId,
              isEncrypted: true,
            ),
          );
        } catch (_) {
          uploadedPictures.add(localPicture);
        }
      } else {
        uploadedPictures.add(localPicture);
      }
    }

    if (pendingOldDriveIds.isNotEmpty) {
      final meta = await _databaseHelper.getDiarySyncMetadata(localDiary.id);
      if (meta != null) {
        await _databaseHelper.updateSyncStatus(
          localDiary.id,
          syncStatus: meta.syncStatus,
          pendingDriveDeletes: [
            ...meta.pendingDriveDeletes,
            ...pendingOldDriveIds,
          ],
        );
      }
    }

    return uploadedPictures;
  }

  Future<Diary> _prepareDiaryForStorage(
    Diary diary, {
    Diary? existing,
  }) async {
    if (!diary.isLocked) {
      if (existing?.isLocked == true && _lockService.sessionPin != null) {
        final pin = _lockService.sessionPin!;
        final decryptedPictures = <Picture>[];
        for (final picture in diary.pictures) {
          if (picture.isLocalFile && picture.isEncrypted) {
            decryptedPictures.add(
              await _encryptionService.decryptLocalPictureFile(picture, pin),
            );
          } else {
            decryptedPictures.add(picture);
          }
        }
        return diary.copyWith(
          pictures: decryptedPictures,
          isLocked: false,
        );
      }
      return diary;
    }

    final pin = _lockService.sessionPin;
    if (pin == null) {
      throw PinRequiredException();
    }

    var plaintext = diary;
    if (existing != null &&
        existing.isLocked &&
        _encryptionService.isEncryptedPayload(existing.content)) {
      plaintext = await _decryptDiaryIfNeeded(existing, pin);
      plaintext = plaintext.copyWith(
        content: diary.content,
        pictures: diary.pictures,
        updateTime: diary.updateTime,
        date: diary.date,
        isDeleted: diary.isDeleted,
      );
    }

    final encrypted =
        await _encryptionService.encryptDiaryFields(plaintext, pin);
    return _encryptLocalPictures(encrypted, pin);
  }

  Future<Diary> _prepareCloudDiaryForStorage(Diary cloudDiary) async {
    if (_driveService.isEncryptedCloudDiary(cloudDiary)) {
      return cloudDiary;
    }

    if (!cloudDiary.isLocked) return cloudDiary;

    final pin = _lockService.sessionPin;
    if (pin == null) {
      return cloudDiary;
    }

    return _encryptionService.encryptDiaryFields(cloudDiary, pin);
  }

  Future<Diary> _prepareDiaryForDisplay(Diary diary) async {
    final pin = _lockService.sessionPin;

    if (diary.isLocked) {
      if (pin == null) {
        return _applyDisplayFallbacks(
          _encryptionService.redactLockedDiary(diary),
        );
      }
      final decrypted = await _decryptDiaryIfNeeded(diary, pin);
      return _resolvePicturesForDisplay(decrypted, pin);
    }

    if (_encryptionService.isEncryptedPayload(diary.content)) {
      if (pin == null) {
        return _applyDisplayFallbacks(diary.copyWith(content: ''));
      }
      final decrypted = await _encryptionService.decryptDiaryFields(diary, pin);
      return _resolvePicturesForDisplay(decrypted, pin);
    }

    if (pin != null) {
      return _resolvePicturesForDisplay(diary, pin);
    }
    return _applyDisplayFallbacks(diary);
  }

  Diary _applyDisplayFallbacks(Diary diary) {
    return diary.copyWith(
      pictures: diary.pictures
          .map((picture) => picture.withDisplayFallback())
          .toList(),
    );
  }

  Future<List<Picture>> _mergePicturesAfterSync(
    List<Picture> localPictures,
    List<Picture> uploadedPictures,
  ) async {
    final merged = <Picture>[];
    for (var i = 0; i < uploadedPictures.length; i++) {
      final uploaded = uploadedPictures[i];
      final local = i < localPictures.length ? localPictures[i] : null;
      merged.add(await _mergePictureAfterSync(local, uploaded));
    }
    return merged;
  }

  Future<Picture> _mergePictureAfterSync(
    Picture? local,
    Picture uploaded,
  ) async {
    if (local != null &&
        local.isLocalFile &&
        local.pictureUrl.isNotEmpty &&
        await File(local.pictureUrl).exists()) {
      return Picture(
        pictureUrl: local.pictureUrl,
        caption: uploaded.caption ?? local.caption,
        isLocalFile: true,
        driveFileId: uploaded.driveFileId ?? local.driveFileId,
        isEncrypted: local.isEncrypted,
      );
    }

    if (uploaded.pictureUrl.isEmpty &&
        uploaded.driveFileId != null &&
        !uploaded.isEncrypted) {
      return Picture.fromUrl(
        Picture.driveThumbnailUrl(uploaded.driveFileId!),
        caption: uploaded.caption,
        driveFileId: uploaded.driveFileId,
      );
    }

    return uploaded;
  }

  Future<Diary> _materializeCloudPictures(Diary diary, String pin) async {
    final pictures = <Picture>[];
    for (final picture in diary.pictures) {
      pictures.add(await _materializeCloudPicture(picture, pin));
    }
    return diary.copyWith(pictures: pictures);
  }

  Future<Picture> _materializeCloudPicture(Picture picture, String pin) async {
    if (picture.isLocalFile || picture.driveFileId == null) {
      return picture;
    }
    if (!_authService.isSignedIn) return picture;

    try {
      final bytes =
          await _driveService.downloadImageBytes(picture.driveFileId!);

      if (picture.isEncrypted) {
        final serialized = utf8.decode(bytes);
        final payload = EncryptedPayload.deserialize(serialized);
        final key = await _encryptionService.deriveKey(pin, payload.salt);
        final decrypted = await _encryptionService.decryptBytes(payload, key);
        final path =
            '${Directory.systemTemp.path}/journal_${picture.driveFileId}.jpg';
        await File(path).writeAsBytes(decrypted);
        return Picture.fromFile(path, caption: picture.caption);
      }

      final path =
          '${Directory.systemTemp.path}/journal_${picture.driveFileId}.jpg';
      await File(path).writeAsBytes(bytes);
      return Picture.fromFile(path, caption: picture.caption);
    } catch (_) {
      return picture;
    }
  }

  Future<Diary> _decryptDiaryIfNeeded(Diary diary, String pin) async {
    if (!diary.isLocked) return diary;
    if (!_encryptionService.isEncryptedPayload(diary.content)) {
      return diary;
    }
    return _encryptionService.decryptDiaryFields(diary, pin);
  }

  Future<Diary> _encryptLocalPictures(Diary diary, String pin) async {
    final pictures = <Picture>[];
    for (final picture in diary.pictures) {
      if (picture.isLocalFile && !picture.isEncrypted) {
        pictures.add(await _encryptionService.encryptLocalPictureFile(
          picture,
          pin,
        ));
      } else {
        pictures.add(picture);
      }
    }

    return Diary(
      id: diary.id,
      createTime: diary.createTime,
      updateTime: diary.updateTime,
      isDeleted: diary.isDeleted,
      date: diary.date,
      content: diary.content,
      pictures: pictures,
      isLocked: diary.isLocked,
    );
  }

  Future<Diary> _decryptLocalPictures(Diary diary, String pin) async {
    final pictures = <Picture>[];
    for (final picture in diary.pictures) {
      if (picture.isLocalFile && picture.isEncrypted) {
        pictures.add(
          await _encryptionService.decryptLocalPictureFile(picture, pin),
        );
      } else {
        pictures.add(picture);
      }
    }

    return Diary(
      id: diary.id,
      createTime: diary.createTime,
      updateTime: diary.updateTime,
      isDeleted: diary.isDeleted,
      date: diary.date,
      content: diary.content,
      pictures: pictures,
      isLocked: diary.isLocked,
    );
  }

  Future<Diary> _resolvePicturesForDisplay(Diary diary, String pin) async {
    final pictures = <Picture>[];
    for (final picture in diary.pictures) {
      pictures.add(await _resolvePictureForDisplay(picture, pin));
    }

    return Diary(
      id: diary.id,
      createTime: diary.createTime,
      updateTime: diary.updateTime,
      isDeleted: diary.isDeleted,
      date: diary.date,
      content: diary.content,
      pictures: pictures,
      isLocked: diary.isLocked,
    );
  }

  Future<Picture> _resolvePictureForDisplay(Picture picture, String pin) async {
    if (picture.isLocalFile && picture.isEncrypted) {
      return _encryptionService.decryptLocalPictureToTemp(picture, pin);
    }

    if (!picture.isLocalFile &&
        picture.driveFileId != null &&
        _authService.isSignedIn) {
      if (picture.isEncrypted) {
        try {
          final bytes =
              await _driveService.downloadImageBytes(picture.driveFileId!);
          final serialized = utf8.decode(bytes);
          final payload = EncryptedPayload.deserialize(serialized);
          final key = await _encryptionService.deriveKey(pin, payload.salt);
          final decrypted =
              await _encryptionService.decryptBytes(payload, key);
          final tempPath =
              '${Directory.systemTemp.path}/journal_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await File(tempPath).writeAsBytes(decrypted);
          return Picture.fromFile(
            tempPath,
            caption: picture.caption,
            isEncrypted: false,
          );
        } catch (_) {
          return picture.withDisplayFallback();
        }
      }

      if (!picture.isValid()) {
        try {
          final bytes =
              await _driveService.downloadImageBytes(picture.driveFileId!);
          final tempPath =
              '${Directory.systemTemp.path}/journal_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await File(tempPath).writeAsBytes(bytes);
          return Picture.fromFile(
            tempPath,
            caption: picture.caption,
          );
        } catch (_) {
          return picture.withDisplayFallback();
        }
      }
    }

    return picture.withDisplayFallback();
  }
}
