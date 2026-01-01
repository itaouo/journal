import 'record.dart';

class Meal extends Record {
  final String mealType;

  Meal({
    required super.id,
    required super.createTime,
    required super.updateTime,
    required super.occurTime,
    required this.mealType,
  });

  // 從 Record 創建 Meal（如果需要的話）
  factory Meal.fromRecord(Record record, String mealType) {
    return Meal(
      id: record.id,
      createTime: record.createTime,
      updateTime: record.updateTime,
      occurTime: record.occurTime,
      mealType: mealType,
    );
  }
}
