import 'diary.dart';
import '../services/diary_sync_service.dart';

class DiaryManager {
  static final DiaryManager _instance = DiaryManager._internal();
  final DiarySyncService _syncService = DiarySyncService();

  factory DiaryManager() {
    return _instance;
  }

  DiaryManager._internal();

  Future<List<Diary>> get diaries async {
    return _syncService.getDiaries();
  }

  Future<void> addDiary(Diary diary, {List<String> removedDriveFileIds = const []}) async {
    await _syncService.saveDiary(diary, removedDriveFileIds: removedDriveFileIds);
  }

  Future<void> updateDiary(Diary updatedDiary, {List<String> removedDriveFileIds = const []}) async {
    await _syncService.saveDiary(updatedDiary, removedDriveFileIds: removedDriveFileIds);
  }

  Future<void> deleteDiary(Diary diary) async {
    await _syncService.deleteDiary(diary);
  }

  Future<void> setDiaryLocked(String id, bool isLocked) async {
    await _syncService.setDiaryLocked(id, isLocked);
  }

  Future<Diary?> getDiaryById(String id) async {
    return _syncService.getDiaryById(id);
  }

  Future<void> syncAllPending() async {
    await _syncService.syncAllPending();
  }

  Future<int> getPendingSyncCount() async {
    return _syncService.getPendingSyncCount();
  }

  Future<RestoreFromCloudResult> restoreFromCloud() async {
    return _syncService.restoreFromCloud();
  }

  Future<bool> needsPinForSync() async {
    return _syncService.needsPinForSync();
  }

  Future<bool> shouldPromptPinBeforeRestore() async {
    return _syncService.shouldPromptPinBeforeRestore();
  }

  Future<void> reencryptAllLockedDiaries(String oldPin, String newPin) async {
    return _syncService.reencryptAllLockedDiaries(oldPin, newPin);
  }

  Future<void> migratePlaintextLockedDiaries() async {
    return _syncService.migratePlaintextLockedDiaries();
  }

  Future<bool> getEncryptAllBackups() async {
    return _syncService.getEncryptAllBackups();
  }

  Future<void> setEncryptAllBackups(bool enabled) async {
    return _syncService.setEncryptAllBackups(enabled);
  }
}
