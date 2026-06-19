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
}
