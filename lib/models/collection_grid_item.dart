import 'package:flutter/material.dart';
import 'diary.dart';
import 'picture.dart';
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

  String get title {
    switch (kind) {
      case CollectionGridKind.diary:
        return '日記 · ${diary!.date.shortDateWithWeekdayString}';
      case CollectionGridKind.review:
        return review!.title;
    }
  }

  String get description {
    switch (kind) {
      case CollectionGridKind.diary:
        return _truncate(diary!.content);
      case CollectionGridKind.review:
        if (review!.summary.isNotEmpty) {
          return _truncate(review!.summary);
        }
        if (review!.thoughts.isNotEmpty) {
          return _truncate(review!.thoughts);
        }
        return '${review!.reviewType.displayName} · ${review!.experienceDate.shortDateWithWeekdayString}';
    }
  }

  Picture? get coverPicture {
    switch (kind) {
      case CollectionGridKind.diary:
        return diary!.pictures.isEmpty ? null : diary!.pictures.first;
      case CollectionGridKind.review:
        return review!.pictures.isEmpty ? null : review!.pictures.first;
    }
  }

  IconData get placeholderIcon {
    switch (kind) {
      case CollectionGridKind.diary:
        return Icons.book_outlined;
      case CollectionGridKind.review:
        return review!.reviewType.icon;
    }
  }

  bool get isLocked => kind == CollectionGridKind.diary && diary!.isLocked;

  static String _truncate(String text, {int maxLength = 80}) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }
}
