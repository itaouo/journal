import 'record.dart';
import 'meal.dart';
import 'database_helper.dart';

class RecordManager {
  static final RecordManager _instance = RecordManager._internal();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  factory RecordManager() {
    return _instance;
  }

  RecordManager._internal();

  // 加載所有記錄
  Future<List<Record>> get records async {
    return await _databaseHelper.getAllRecords();
  }

  // 添加記錄到數據庫
  Future<void> addRecord(Record record) async {
    await _databaseHelper.insertRecord(record);
  }

  // 更新數據庫中的記錄
  Future<void> updateRecord(Record updatedRecord) async {
    await _databaseHelper.updateRecord(updatedRecord);
  }

  // 從數據庫刪除記錄
  Future<void> deleteRecord(String id) async {
    await _databaseHelper.deleteRecord(id);
  }

  // 根據 ID 獲取記錄
  Future<Record?> getRecordById(String id) async {
    return await _databaseHelper.getRecord(id);
  }

  // 檢查特定日期和餐食類型是否有記錄
  Future<bool> hasRecordForDateAndMealType(DateTime date, String mealType) async {
    final records = await _databaseHelper.getAllRecords();
    final dateOnly = DateTime(date.year, date.month, date.day);

    return records.any((record) {
      if (record is! Meal || record.mealType != mealType) return false;
      final recordDate = DateTime(record.occurTime.year, record.occurTime.month, record.occurTime.day);
      return recordDate.isAtSameMomentAs(dateOnly);
    });
  }

  // 刪除特定日期和餐食類型的記錄
  Future<void> deleteRecordForDateAndMealType(DateTime date, String mealType) async {
    final records = await _databaseHelper.getAllRecords();
    final dateOnly = DateTime(date.year, date.month, date.day);

    for (final record in records) {
      if (record is Meal && record.mealType == mealType) {
        final recordDate = DateTime(record.occurTime.year, record.occurTime.month, record.occurTime.day);
        if (recordDate.isAtSameMomentAs(dateOnly)) {
          await _databaseHelper.deleteRecord(record.id);
          break; // 只刪除第一個匹配的記錄
        }
      }
    }
  }
}
