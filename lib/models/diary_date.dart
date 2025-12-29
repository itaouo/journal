class DiaryDate {
  final DateTime dateTime;

  DiaryDate(this.dateTime);

  /// 獲取星期格式的日期字串
  /// 例如: "2024年12月26日 星期四"
  String toWeekdayString() {
    final weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final weekday = weekdays[dateTime.weekday - 1];

    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日 $weekday';
  }

  /// 獲取簡短的星期格式
  /// 例如: "12月26日 周四"
  String toShortWeekdayString() {
    final shortWeekdays = ['（一）', '（二）', '（三）', '（四）', '（五）', '（六）', '（日）'];
    final weekday = shortWeekdays[dateTime.weekday - 1];

    return '${dateTime.month}月${dateTime.day}日$weekday';
  }

  /// 獲取英文星期格式
  /// 例如: "December 26, 2024 (Thursday)"
  String toEnglishWeekdayString() {
    final englishMonths = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final englishWeekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];

    final month = englishMonths[dateTime.month - 1];
    final weekday = englishWeekdays[dateTime.weekday - 1];

    return '$month ${dateTime.day}, ${dateTime.year} ($weekday)';
  }

  /// 檢查是否是今天
  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
           dateTime.month == now.month &&
           dateTime.day == now.day;
  }

  /// 檢查是否是昨天
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
           dateTime.month == yesterday.month &&
           dateTime.day == yesterday.day;
  }

  /// 獲取相對日期描述
  String get relativeDateString {
    if (isToday) return '今天';
    if (isYesterday) return '昨天';

    final now = DateTime.now();
    final difference = now.difference(dateTime).inDays;

    if (difference > 0 && difference <= 7) {
      return '$difference天前';
    }

    return toShortWeekdayString();
  }

  /// 獲取簡短日期格式 (MM/DD)
  /// 例如: "12/17"
  String get shortDateString {
    return '${dateTime.month}/${dateTime.day}';
  }

  /// 獲取簡短日期格式含星期 (MM/DD（weekday）)
  /// 例如: "12/17（一）"
  String get shortDateWithWeekdayString {
    final shortWeekdays = ['（一）', '（二）', '（三）', '（四）', '（五）', '（六）', '（日）'];
    final weekday = shortWeekdays[dateTime.weekday - 1];
    return '${dateTime.month}/${dateTime.day}$weekday';
  }

  /// 比較兩個 DiaryDate
  bool isSameDay(DiaryDate other) {
    return dateTime.year == other.dateTime.year &&
           dateTime.month == other.dateTime.month &&
           dateTime.day == other.dateTime.day;
  }

  /// 比較是否在同一個星期
  bool isSameWeek(DiaryDate other) {
    final startOfWeek1 = dateTime.subtract(Duration(days: dateTime.weekday - 1));
    final startOfWeek2 = other.dateTime.subtract(Duration(days: other.dateTime.weekday - 1));

    return startOfWeek1.year == startOfWeek2.year &&
           startOfWeek1.month == startOfWeek2.month &&
           startOfWeek1.day == startOfWeek2.day;
  }

  /// 獲取這個星期的第一天 (星期一)
  DiaryDate get startOfWeek {
    final monday = dateTime.subtract(Duration(days: dateTime.weekday - 1));
    return DiaryDate(DateTime(monday.year, monday.month, monday.day));
  }

  /// 獲取這個星期的最後一天 (星期日)
  DiaryDate get endOfWeek {
    final sunday = dateTime.add(Duration(days: 7 - dateTime.weekday));
    return DiaryDate(DateTime(sunday.year, sunday.month, sunday.day));
  }

  /// 複製並修改
  DiaryDate copyWith({
    int? year,
    int? month,
    int? day,
  }) {
    return DiaryDate(DateTime(
      year ?? dateTime.year,
      month ?? dateTime.month,
      day ?? dateTime.day,
    ));
  }

  /// 從 DateTime 創建
  factory DiaryDate.fromDateTime(DateTime dateTime) {
    return DiaryDate(dateTime);
  }

  /// 從字串解析 (格式: YYYY-MM-DD)
  factory DiaryDate.fromString(String dateString) {
    final parts = dateString.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid date format. Expected: YYYY-MM-DD');
    }
    return DiaryDate(DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    ));
  }

  /// 轉換為字串 (格式: YYYY-MM-DD)
  String toDateString() {
    return '${dateTime.year.toString().padLeft(4, '0')}-'
           '${dateTime.month.toString().padLeft(2, '0')}-'
           '${dateTime.day.toString().padLeft(2, '0')}';
  }

  /// 比較操作符
  bool operator >(DiaryDate other) => dateTime.isAfter(other.dateTime);
  bool operator <(DiaryDate other) => dateTime.isBefore(other.dateTime);
  bool operator >=(DiaryDate other) => dateTime.isAfter(other.dateTime) || isSameDay(other);
  bool operator <=(DiaryDate other) => dateTime.isBefore(other.dateTime) || isSameDay(other);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiaryDate && dateTime == other.dateTime;
  }

  @override
  int get hashCode => dateTime.hashCode;

  @override
  String toString() {
    return 'DiaryDate(${toWeekdayString()})';
  }
}


