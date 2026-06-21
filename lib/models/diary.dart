import 'picture.dart';
import 'collection.dart';
import 'diary_date.dart';

class Diary extends Collection {
  final DiaryDate date;
  final String content;
  final List<Picture> pictures;
  final bool isLocked;

  Diary({
    required String id,
    required DateTime createTime,
    required DateTime updateTime,
    bool isDeleted = false,
    required this.date,
    required this.content,
    List<Picture>? pictures,
    this.isLocked = false,
  }) : pictures = pictures ?? [],
        super(
          id: id,
          createTime: createTime,
          updateTime: updateTime,
          isDeleted: isDeleted,
        );

  /// 從 DateTime 創建 Diary 的工廠方法
  factory Diary.fromDateTime({
    required String id,
    required DateTime createTime,
    required DateTime updateTime,
    bool isDeleted = false,
    required DateTime date,
    required String content,
    List<Picture>? pictures,
    bool isLocked = false,
  }) {
    return Diary(
      id: id,
      createTime: createTime,
      updateTime: updateTime,
      isDeleted: isDeleted,
      date: DiaryDate.fromDateTime(date),
      content: content,
      pictures: pictures,
      isLocked: isLocked,
    );
  }

  Diary copyWith({
    String? content,
    List<Picture>? pictures,
    bool? isLocked,
    DateTime? updateTime,
    DiaryDate? date,
    bool? isDeleted,
  }) {
    return Diary(
      id: id,
      createTime: createTime,
      updateTime: updateTime ?? this.updateTime,
      isDeleted: isDeleted ?? this.isDeleted,
      date: date ?? this.date,
      content: content ?? this.content,
      pictures: pictures ?? this.pictures,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}