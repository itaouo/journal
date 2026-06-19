import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/database_helper.dart';
import '../models/diary.dart';
import '../models/picture.dart';
import 'auth_service.dart';
import 'google_drive_service.dart';

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

  final Set<String> _syncInProgress = {};

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<List<Diary>> getDiaries() async {
    return _databaseHelper.getAllDiaries();
  }

  Future<Diary?> getDiaryById(String id) async {
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

    if (existing != null) {
      await _databaseHelper.updateDiary(
        diary,
        syncStatus: DiarySyncMetadata.statusPending,
        pendingDriveDeletes: pendingDeletes,
      );
    } else {
      await _databaseHelper.insertDiary(
        diary,
        syncStatus: DiarySyncMetadata.statusPending,
        pendingDriveDeletes: pendingDeletes,
      );
    }

    _scheduleBackgroundSync(diary.id);
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
      final cloudDiary = await _driveService.downloadDiaryJson(driveFile.fileId);
      if (cloudDiary.isDeleted) {
        skippedCount++;
        continue;
      }

      final localDiary = await _databaseHelper.getDiary(cloudDiary.id);
      if (localDiary == null ||
          cloudDiary.updateTime.isAfter(localDiary.updateTime)) {
        await _databaseHelper.upsertDiaryFromCloud(
          cloudDiary,
          driveJsonFileId: driveFile.fileId,
        );
        restoredCount++;
      } else {
        skippedCount++;
      }
    }

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
      final diary = await _databaseHelper.getDiary(diaryId);
      if (diary == null) return;

      final meta = await _databaseHelper.getDiarySyncMetadata(diaryId);
      if (meta == null) return;

      for (final fileId in meta.pendingDriveDeletes) {
        try {
          await _driveService.deleteFile(fileId);
        } catch (_) {}
      }

      final uploadedPictures = await _uploadLocalPictures(diary);
      final cloudDiary = Diary(
        id: diary.id,
        createTime: diary.createTime,
        updateTime: diary.updateTime,
        isDeleted: diary.isDeleted,
        date: diary.date,
        content: diary.content,
        pictures: uploadedPictures,
      );

      final driveJsonFileId = meta.driveJsonFileId == null
          ? await _driveService.uploadDiaryJson(cloudDiary)
          : await _driveService.updateDiaryJson(
              cloudDiary,
              meta.driveJsonFileId!,
            );

      await _databaseHelper.updateDiary(
        cloudDiary,
        syncStatus: DiarySyncMetadata.statusSynced,
        driveJsonFileId: driveJsonFileId,
        pendingDriveDeletes: const [],
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

  Future<List<Picture>> _uploadLocalPictures(Diary diary) async {
    final uploadedPictures = <Picture>[];

    for (var i = 0; i < diary.pictures.length; i++) {
      final picture = diary.pictures[i];
      if (picture.isLocalFile) {
        final file = File(picture.pictureUrl);
        final uploaded = await _driveService.uploadImage(
          file,
          '${diary.id}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
        );
        uploadedPictures.add(
          Picture.fromUrl(
            uploaded.pictureUrl,
            caption: picture.caption,
            driveFileId: uploaded.fileId,
          ),
        );
      } else {
        uploadedPictures.add(picture);
      }
    }

    return uploadedPictures;
  }
}
