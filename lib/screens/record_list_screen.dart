import 'package:flutter/material.dart';
import '../models/meal_manager.dart';
import '../models/meal.dart';

class RecordListScreen extends StatefulWidget {
  const RecordListScreen({super.key});

  @override
  State<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends State<RecordListScreen> {
  final MealManager _mealManager = MealManager();
  late Future<List<Meal>> _mealsFuture;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  void _loadMeals() {
    _mealsFuture = _mealManager.meals;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getMealTypeDisplayName(String? mealType) {
    if (mealType == null) return '未知餐食';

    switch (mealType) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '宵夜';
      default:
        return mealType;
    }
  }

  IconData _getMealTypeIcon(String? mealType) {
    switch (mealType) {
      case 'breakfast':
        return Icons.brightness_5;
      case 'lunch':
        return Icons.brightness_7;
      case 'dinner':
        return Icons.dark_mode_outlined;
      case 'snack':
        return Icons.cookie_outlined;
      default:
        return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('記錄列表'),
        backgroundColor: Theme.of(context).secondaryHeaderColor,
      ),
      body: FutureBuilder<List<Meal>>(
        future: _mealsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('載入失敗: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                '還沒有任何記錄',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          } else {
            final meals = snapshot.data!;
            // 按創建時間降序排列（最新的在前面）
            meals.sort((a, b) => b.createTime.compareTo(a.createTime));

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: meals.length,
              itemBuilder: (context, index) {
                final meal = meals[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.restaurant,
                              size: 20,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Meals - ${_getMealTypeDisplayName(meal.mealType)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _formatDateTime(meal.occurTime),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
