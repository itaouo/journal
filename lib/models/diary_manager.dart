import 'diary.dart';
import 'picture.dart';

class DiaryManager {
  static final DiaryManager _instance = DiaryManager._internal();
  final List<Diary> _diaries = [];

  factory DiaryManager() {
    return _instance;
  }

  DiaryManager._internal();

  List<Diary> get diaries => List.unmodifiable(_diaries);

  void addDiary(Diary diary) {
    _diaries.add(diary);
  }

  void updateDiary(String id, Diary updatedDiary) {
    final index = _diaries.indexWhere((diary) => diary.id == id);
    if (index != -1) {
      _diaries[index] = updatedDiary;
    }
  }

  void deleteDiary(String id) {
    _diaries.removeWhere((diary) => diary.id == id);
  }

  Diary? getDiaryById(String id) {
    return _diaries.where((diary) => diary.id == id).firstOrNull;
  }
}


