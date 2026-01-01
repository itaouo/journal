import 'record.dart';

/// 餐食類型介面 - 允許完全客製化
abstract class MealTypeInterface {
  String get id;
  String get displayName;
  String? get description;
  String? get icon;

  /// 比較兩個餐食類型是否相同
  bool equals(MealTypeInterface other) => id == other.id;
}

/// 預設餐食類型實現
class DefaultMealType implements MealTypeInterface {
  @override
  final String id;
  @override
  final String displayName;
  @override
  final String? description;
  @override
  final String? icon;

  const DefaultMealType({
    required this.id,
    required this.displayName,
    this.description,
    this.icon,
  });

  // 預定義的餐食類型
  static const DefaultMealType breakfast = DefaultMealType(
    id: 'breakfast',
    displayName: '早餐',
    description: '早晨的餐食',
    icon: '🌅',
  );

  static const DefaultMealType lunch = DefaultMealType(
    id: 'lunch',
    displayName: '午餐',
    description: '中午的餐食',
    icon: '☀️',
  );

  static const DefaultMealType dinner = DefaultMealType(
    id: 'dinner',
    displayName: '晚餐',
    description: '晚上的餐食',
    icon: '🌙',
  );

  static const DefaultMealType snack = DefaultMealType(
    id: 'snack',
    displayName: '宵夜',
    description: '睡前小點心',
    icon: '🍪',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DefaultMealType && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DefaultMealType($id: $displayName)';
}

/// 餐食類型管理器 - 負責管理所有餐食類型
class MealTypeManager {
  static final MealTypeManager _instance = MealTypeManager._internal();
  factory MealTypeManager() => _instance;

  MealTypeManager._internal() {
    // 初始化預設餐食類型
    _registerDefaultTypes();
  }

  final Map<String, MealTypeInterface> _mealTypes = {};

  void _registerDefaultTypes() {
    registerMealType(DefaultMealType.breakfast);
    registerMealType(DefaultMealType.lunch);
    registerMealType(DefaultMealType.dinner);
    registerMealType(DefaultMealType.snack);
  }

  /// 註冊新的餐食類型
  void registerMealType(MealTypeInterface mealType) {
    _mealTypes[mealType.id] = mealType;
  }

  /// 取消註冊餐食類型
  void unregisterMealType(String id) {
    _mealTypes.remove(id);
  }

  /// 獲取餐食類型
  MealTypeInterface? getMealType(String id) => _mealTypes[id];

  /// 獲取所有餐食類型
  List<MealTypeInterface> get allMealTypes => _mealTypes.values.toList();

  /// 從ID創建餐食類型
  MealTypeInterface? createFromId(String id) => getMealType(id);

  /// 檢查餐食類型是否存在
  bool hasMealType(String id) => _mealTypes.containsKey(id);

  /// 清空所有客製化餐食類型（保留預設的）
  void clearCustomMealTypes() {
    _mealTypes.clear();
    _registerDefaultTypes();
  }
}

/// 客製化餐食類型 - 用戶可以輕鬆創建
class CustomMealType implements MealTypeInterface {
  @override
  final String id;
  @override
  final String displayName;
  @override
  final String? description;
  @override
  final String? icon;

  CustomMealType({
    required this.id,
    required this.displayName,
    this.description,
    this.icon,
  }) {
    // 自動註冊到管理器
    MealTypeManager().registerMealType(this);
  }

  factory CustomMealType.create({
    required String id,
    required String displayName,
    String? description,
    String? icon,
  }) {
    // 檢查是否已存在
    if (MealTypeManager().hasMealType(id)) {
      throw ArgumentError('MealType with id "$id" already exists');
    }

    return CustomMealType(
      id: id,
      displayName: displayName,
      description: description,
      icon: icon,
    );
  }

  @override
  String toString() => 'CustomMealType($id: $displayName)';
}

class RegularMeal extends Record {
  final MealTypeInterface mealType;

  RegularMeal({
    required String id,
    required DateTime createTime,
    required DateTime updateTime,
    required DateTime occurTime,
    required this.mealType,
  }) : super(
          id: id,
          createTime: createTime,
          updateTime: updateTime,
          occurTime: occurTime,
        );

  /// 使用ID創建RegularMeal
  factory RegularMeal.fromMealTypeId({
    required String id,
    required DateTime createTime,
    required DateTime updateTime,
    required DateTime occurTime,
    required String mealTypeId,
  }) {
    final mealType = MealTypeManager().getMealType(mealTypeId);
    if (mealType == null) {
      throw ArgumentError('Unknown meal type: $mealTypeId');
    }

    return RegularMeal(
      id: id,
      createTime: createTime,
      updateTime: updateTime,
      occurTime: occurTime,
      mealType: mealType,
    );
  }

  /// 獲取所有可用的餐食類型
  static List<MealTypeInterface> get allMealTypes => MealTypeManager().allMealTypes;

  /// 獲取顯示名稱
  String get mealTypeDisplayName => mealType.displayName;

  /// 獲取描述
  String? get mealTypeDescription => mealType.description;

  /// 獲取圖標
  String? get mealTypeIcon => mealType.icon;

  @override
  String toString() {
    return 'RegularMeal(id: $id, mealType: $mealTypeDisplayName, createTime: $createTime, updateTime: $updateTime)';
  }
}
