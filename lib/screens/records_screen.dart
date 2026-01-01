import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_manager.dart';
import '../models/meal.dart';
import 'record_list_screen.dart';

class RecordsScreen extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const RecordsScreen({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final MealManager _mealManager = MealManager();
  final Uuid _uuid = Uuid();
  final Set<String> _existingMealTypes = {};

  @override
  void initState() {
    super.initState();
    _checkExistingRecords();
  }

  @override
  void didUpdateWidget(RecordsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _checkExistingRecords();
    }
  }

  Future<void> _checkExistingRecords() async {
    final existingTypes = <String>{};
    for (final mealType in ['breakfast', 'lunch', 'dinner', 'snack']) {
      final hasRecord = await _mealManager.hasMealForDateAndMealType(widget.selectedDate, mealType);
      if (hasRecord) {
        existingTypes.add(mealType);
      }
    }
    setState(() {
      _existingMealTypes.clear();
      _existingMealTypes.addAll(existingTypes);
    });
  }

  Future<void> _addRecord(String mealType) async {
    try {
      final now = DateTime.now();
      // 使用選擇的日期，但保留當前的時間
      final updateTime = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        now.hour,
        now.minute + 15,
        now.second,
      );

      final meal = Meal(
        id: _uuid.v4(),
        createTime: now,
        updateTime: updateTime,
        occurTime: updateTime,
        mealType: mealType,
      );

      await _mealManager.addMeal(meal);

      // 更新已存在的餐食類型
      setState(() {
        _existingMealTypes.add(mealType);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已新增 $mealType 記錄 (${widget.selectedDate.toString().split(' ')[0]})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增記錄失敗: $e')),
        );
      }
    }
  }

  Future<void> _deleteRecord(String mealType) async {
    try {
      await _mealManager.deleteMealForDateAndMealType(widget.selectedDate, mealType);

      // 更新已存在的餐食類型
      setState(() {
        _existingMealTypes.remove(mealType);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已刪除 $mealType 記錄 (${widget.selectedDate.toString().split(' ')[0]})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除記錄失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Meals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMealButton('早餐', Icons.brightness_5, 'breakfast'),
                    _buildMealButton('午餐', Icons.brightness_7, 'lunch'),
                    _buildMealButton('晚餐', Icons.dark_mode_outlined, 'dinner'),
                    _buildMealButton('宵夜', Icons.cookie_outlined, 'snack'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealButton(String title, IconData icon, String mealType) {
    final hasRecord = _existingMealTypes.contains(mealType);

    return ElevatedButton(
      onPressed: () => hasRecord ? _deleteRecord(mealType) : _addRecord(mealType),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: hasRecord ? Colors.purple.shade800 : null,
        foregroundColor: hasRecord ? Colors.white : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
