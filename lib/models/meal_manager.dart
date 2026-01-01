import 'meal.dart';
import 'database_helper.dart';

class MealManager {
  static final MealManager _instance = MealManager._internal();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  factory MealManager() {
    return _instance;
  }

  MealManager._internal();

  // 加載所有餐食記錄
  Future<List<Meal>> get meals async {
    final records = await _databaseHelper.getAllMeals();
    return records;
  }

  // 添加餐食記錄到數據庫
  Future<void> addMeal(Meal meal) async {
    await _databaseHelper.insertMeal(meal);
  }

  // 更新數據庫中的餐食記錄
  Future<void> updateMeal(Meal updatedMeal) async {
    await _databaseHelper.updateMeal(updatedMeal);
  }

  // 從數據庫刪除餐食記錄
  Future<void> deleteMeal(String id) async {
    await _databaseHelper.deleteMeal(id);
  }

  // 根據 ID 獲取餐食記錄
  Future<Meal?> getMealById(String id) async {
    return await _databaseHelper.getMeal(id);
  }

  // 檢查特定日期和餐食類型是否有記錄
  Future<bool> hasMealForDateAndMealType(DateTime date, String mealType) async {
    final meals = await this.meals;
    final dateOnly = DateTime(date.year, date.month, date.day);

    return meals.any((meal) {
      if (meal.mealType != mealType) return false;
      final mealDate = DateTime(meal.updateTime.year, meal.updateTime.month, meal.updateTime.day);
      return mealDate.isAtSameMomentAs(dateOnly);
    });
  }

  // 刪除特定日期和餐食類型的記錄
  Future<void> deleteMealForDateAndMealType(DateTime date, String mealType) async {
    final meals = await this.meals;
    final dateOnly = DateTime(date.year, date.month, date.day);

    for (final meal in meals) {
      if (meal.mealType == mealType) {
        final mealDate = DateTime(meal.updateTime.year, meal.updateTime.month, meal.updateTime.day);
        if (mealDate.isAtSameMomentAs(dateOnly)) {
          await _databaseHelper.deleteMeal(meal.id);
          break; // 只刪除第一個匹配的記錄
        }
      }
    }
  }
}
