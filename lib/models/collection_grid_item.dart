import 'diary.dart';
import 'review.dart';

enum CollectionGridKind { diary, review }

class CollectionGridItem {
  final CollectionGridKind kind;
  final DateTime sortDate;
  final Diary? diary;
  final Review? review;

  const CollectionGridItem._({
    required this.kind,
    required this.sortDate,
    this.diary,
    this.review,
  });

  factory CollectionGridItem.fromDiary(Diary diary) {
    return CollectionGridItem._(
      kind: CollectionGridKind.diary,
      sortDate: diary.date.dateTime,
      diary: diary,
    );
  }

  factory CollectionGridItem.fromReview(Review review) {
    return CollectionGridItem._(
      kind: CollectionGridKind.review,
      sortDate: review.experienceDate.dateTime,
      review: review,
    );
  }

  static List<CollectionGridItem> mergeAndSort(
    List<Diary> diaries,
    List<Review> reviews,
  ) {
    final items = <CollectionGridItem>[
      ...diaries.map(CollectionGridItem.fromDiary),
      ...reviews.map(CollectionGridItem.fromReview),
    ];
    items.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    return items;
  }
}
