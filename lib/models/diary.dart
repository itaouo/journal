import 'picture.dart';
import 'collection.dart';
import 'diary_date.dart';
import 'mood.dart';

class Diary extends Collection {
  final DiaryDate date;
  final String content;
  final List<Picture> pictures;
  final String? location;
  final Mood? mood;

  Diary({
    required String id,
    required DateTime createTime,
    required DateTime updateTime,
    bool isDeleted = false,
    required this.date,
    required this.content,
    List<Picture>? pictures,
    this.location,
    this.mood,
  }) : pictures = pictures ?? [],
        super(
          id: id,
          createTime: createTime,
          updateTime: updateTime,
          isDeleted: isDeleted,
        ) {
    // invariant: 如果提供了心情，必須是有效的 Mood 實例
    assert(mood == null || mood is Mood, 'mood must be a valid Mood instance or null');
  }

  /// 從 DateTime 創建 Diary 的工廠方法
  factory Diary.fromDateTime({
    required String id,
    required DateTime createTime,
    required DateTime updateTime,
    bool isDeleted = false,
    required DateTime date,
    required String content,
    List<Picture>? pictures,
    String? location,
    String? moodString,
  }) {
    return Diary(
      id: id,
      createTime: createTime,
      updateTime: updateTime,
      isDeleted: isDeleted,
      date: DiaryDate.fromDateTime(date),
      content: content,
      pictures: pictures,
      location: location,
      mood: Mood.fromString(moodString),
    );
  }
}