import 'package:flutter/material.dart';
import 'diary.dart';
import 'custom_entry.dart';
import 'picture.dart';
import 'review.dart';

enum CollectionGridKind { diary, review, custom }

class CollectionGridItem {
  final CollectionGridKind kind;
  final DateTime sortDate;
  final Diary? diary;
  final Review? review;
  final CustomEntry? customEntry;
  final String? customTemplateName;
  final IconData? customTemplateIcon;

  const CollectionGridItem._({
    required this.kind,
    required this.sortDate,
    this.diary,
    this.review,
    this.customEntry,
    this.customTemplateName,
    this.customTemplateIcon,
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

  factory CollectionGridItem.fromCustomEntry(
    CustomEntry entry, {
    required String templateName,
    required IconData templateIcon,
  }) {
    return CollectionGridItem._(
      kind: CollectionGridKind.custom,
      sortDate: entry.updateTime,
      customEntry: entry,
      customTemplateName: templateName,
      customTemplateIcon: templateIcon,
    );
  }

  static List<CollectionGridItem> mergeAndSort(
    List<Diary> diaries,
    List<Review> reviews,
    List<CollectionGridItem> customItems,
  ) {
    final items = <CollectionGridItem>[
      ...diaries.map(CollectionGridItem.fromDiary),
      ...reviews.map(CollectionGridItem.fromReview),
      ...customItems,
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
      case CollectionGridKind.custom:
        return customTemplateName ?? '自訂模板';
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
      case CollectionGridKind.custom:
        final fields = customEntry!.fieldValues.values.whereType<String>();
        final first = fields.firstWhere(
          (value) => value.trim().isNotEmpty,
          orElse: () => '',
        );
        if (first.isNotEmpty) return _truncate(first);
        return '自訂內容';
    }
  }

  Picture? get coverPicture {
    switch (kind) {
      case CollectionGridKind.diary:
        return diary!.pictures.isEmpty ? null : diary!.pictures.first;
      case CollectionGridKind.review:
        return review!.pictures.isEmpty ? null : review!.pictures.first;
      case CollectionGridKind.custom:
        final values = customEntry!.fieldValues.values;
        for (final value in values) {
          if (value is List && value.isNotEmpty) {
            final first = value.first;
            if (first is String && first.isNotEmpty) {
              return Picture.fromFile(first);
            }
          }
        }
        return null;
    }
  }

  IconData get placeholderIcon {
    switch (kind) {
      case CollectionGridKind.diary:
        return Icons.book_outlined;
      case CollectionGridKind.review:
        return review!.reviewType.icon;
      case CollectionGridKind.custom:
        return customTemplateIcon ?? Icons.note_outlined;
    }
  }

  bool get isLocked {
    if (kind == CollectionGridKind.diary) return diary!.isLocked;
    if (kind == CollectionGridKind.custom) return customEntry!.isLocked;
    return false;
  }

  static String _truncate(String text, {int maxLength = 80}) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }
}
