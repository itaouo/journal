class Mood {
  final String value;
  final String? why;

  const Mood._(this.value, [this.why]);

  /// 驗證 invariant：確保心情值是預定義的有效值
  static bool _isValidMood(String value) {
    return _allMoods.containsKey(value);
  }

  /// 從字串創建 Mood，如果無效則拋出異常
  factory Mood(String value, [String? why]) {
    if (!_isValidMood(value)) {
      throw ArgumentError('Invalid mood: $value. Must be one of: ${_allMoods.keys.join(', ')}');
    }
    return Mood._(value, why);
  }

  /// 從字串創建 Mood，如果無效則返回 null
  static Mood? fromString(String? value, [String? why]) {
    if (value == null || !_isValidMood(value)) {
      return null;
    }
    return Mood._(value, why);
  }

  /// 從字串和原因創建 Mood（完整版本）
  factory Mood.withReason(String value, String? why) {
    if (!_isValidMood(value)) {
      throw ArgumentError('Invalid mood: $value. Must be one of: ${_allMoods.keys.join(', ')}');
    }
    return Mood._(value, why);
  }

  // 預定義的心情常量
  static final Mood happy = Mood._('happy');
  static final Mood sad = Mood._('sad');
  static final Mood excited = Mood._('excited');
  static final Mood calm = Mood._('calm');
  static final Mood angry = Mood._('angry');
  static final Mood tired = Mood._('tired');
  static final Mood relaxed = Mood._('relaxed');
  static final Mood anxious = Mood._('anxious');
  static final Mood grateful = Mood._('grateful');
  static final Mood hopeful = Mood._('hopeful');

  /// 所有心情的映射表，包含顯示名稱和表情符號
  static const Map<String, Map<String, String>> _allMoods = {
    'happy': {'name': '開心', 'emoji': '😊'},
    'sad': {'name': '難過', 'emoji': '😢'},
    'excited': {'name': '興奮', 'emoji': '🤩'},
    'calm': {'name': '平靜', 'emoji': '😌'},
    'angry': {'name': '生氣', 'emoji': '😠'},
    'tired': {'name': '疲憊', 'emoji': '😴'},
    'relaxed': {'name': '放鬆', 'emoji': '😎'},
    'anxious': {'name': '焦慮', 'emoji': '😰'},
    'grateful': {'name': '感恩', 'emoji': '🙏'},
    'hopeful': {'name': '期待', 'emoji': '🌟'},
  };

  /// 獲取顯示名稱
  String get displayName => _allMoods[value]!['name']!;

  /// 獲取表情符號
  String get emoji => _allMoods[value]!['emoji']!;

  /// 獲取完整顯示文字 (表情符號 + 名稱)
  String get fullDisplay => '$emoji $displayName';

  /// 檢查是否有原因說明
  bool get hasReason => why != null && why!.isNotEmpty;

  /// 獲取完整描述 (包含原因)
  String get fullDescription {
    if (hasReason) {
      return '$fullDisplay - $why';
    }
    return fullDisplay;
  }

  /// 複製並修改原因
  Mood copyWith({String? why}) {
    return Mood._(value, why ?? this.why);
  }

  /// 創建帶有原因的新實例
  Mood withReason(String? reason) {
    return Mood._(value, reason);
  }

  /// 獲取所有可用的心情列表
  static List<Mood> get allMoods {
    return _allMoods.keys.map((key) => Mood._(key)).toList();
  }

  /// 檢查是否為正面心情
  bool get isPositive {
    const positiveMoods = ['happy', 'excited', 'calm', 'relaxed', 'grateful', 'hopeful'];
    return positiveMoods.contains(value);
  }

  /// 檢查是否為負面心情
  bool get isNegative {
    const negativeMoods = ['sad', 'angry', 'tired', 'anxious'];
    return negativeMoods.contains(value);
  }

  /// 檢查是否為中性心情
  bool get isNeutral => !isPositive && !isNegative;

  /// 根據心情獲取建議的顏色
  String get suggestedColor {
    switch (value) {
      case 'happy':
      case 'excited':
        return 'yellow';
      case 'sad':
      case 'anxious':
        return 'blue';
      case 'angry':
        return 'red';
      case 'calm':
      case 'relaxed':
        return 'green';
      case 'tired':
        return 'purple';
      case 'grateful':
      case 'hopeful':
        return 'orange';
      default:
        return 'grey';
    }
  }

  /// 複製當前心情（由於是不可變的，返回自己）
  Mood copy() => this;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mood && other.value == value && other.why == why;
  }

  @override
  int get hashCode => value.hashCode ^ why.hashCode;

  @override
  String toString() {
    if (hasReason) {
      return 'Mood($value: $fullDisplay, why: "$why")';
    }
    return 'Mood($value: $fullDisplay)';
  }
}
