import 'package:flutter/material.dart';

enum ReviewType {
  movie,
  theater,
  book,
  other;

  String get displayName {
    switch (this) {
      case ReviewType.movie:
        return '電影';
      case ReviewType.theater:
        return '劇場';
      case ReviewType.book:
        return '讀書';
      case ReviewType.other:
        return '其他';
    }
  }

  IconData get icon {
    switch (this) {
      case ReviewType.movie:
        return Icons.movie_outlined;
      case ReviewType.theater:
        return Icons.theater_comedy_outlined;
      case ReviewType.book:
        return Icons.menu_book_outlined;
      case ReviewType.other:
        return Icons.rate_review_outlined;
    }
  }

  static ReviewType fromString(String value) {
    return ReviewType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ReviewType.other,
    );
  }
}
