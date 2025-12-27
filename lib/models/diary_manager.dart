import 'diary.dart';
import 'picture.dart';
import 'database_helper.dart';

class DiaryManager {
  static final DiaryManager _instance = DiaryManager._internal();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  factory DiaryManager() {
    return _instance;
  }

  DiaryManager._internal();

  // 加載所有日記
  Future<List<Diary>> get diaries async {
    return await _databaseHelper.getAllDiaries();
  }

  // 添加日記到數據庫
  Future<void> addDiary(Diary diary) async {
    await _databaseHelper.insertDiary(diary);
  }

  // 更新數據庫中的日記
  Future<void> updateDiary(Diary updatedDiary) async {
    await _databaseHelper.updateDiary(updatedDiary);
  }

  // 從數據庫刪除日記
  Future<void> deleteDiary(String id) async {
    await _databaseHelper.deleteDiary(id);
  }

  // 根據 ID 獲取日記
  Future<Diary?> getDiaryById(String id) async {
    return await _databaseHelper.getDiary(id);
  }
}


