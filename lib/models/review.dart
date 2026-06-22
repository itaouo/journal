import 'collection.dart';
import 'diary_date.dart';
import 'picture.dart';
import 'review_type.dart';

class Review extends Collection {
  final ReviewType reviewType;
  final String title;
  final String summary;
  final String keyQuotes;
  final String thoughts;
  final int? rating;
  final String? ratingNote;
  final DiaryDate experienceDate;
  final List<Picture> pictures;

  Review({
    required String id,
    required DateTime createTime,
    required DateTime updateTime,
    bool isDeleted = false,
    required this.reviewType,
    required this.title,
    this.summary = '',
    this.keyQuotes = '',
    this.thoughts = '',
    this.rating,
    this.ratingNote,
    required this.experienceDate,
    List<Picture>? pictures,
  })  : pictures = pictures ?? [],
        super(
          id: id,
          createTime: createTime,
          updateTime: updateTime,
          isDeleted: isDeleted,
        );

  Review copyWith({
    ReviewType? reviewType,
    String? title,
    String? summary,
    String? keyQuotes,
    String? thoughts,
    int? rating,
    String? ratingNote,
    DiaryDate? experienceDate,
    List<Picture>? pictures,
    DateTime? updateTime,
    bool? isDeleted,
    bool clearRating = false,
    bool clearRatingNote = false,
  }) {
    return Review(
      id: id,
      createTime: createTime,
      updateTime: updateTime ?? this.updateTime,
      isDeleted: isDeleted ?? this.isDeleted,
      reviewType: reviewType ?? this.reviewType,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      keyQuotes: keyQuotes ?? this.keyQuotes,
      thoughts: thoughts ?? this.thoughts,
      rating: clearRating ? null : (rating ?? this.rating),
      ratingNote: clearRatingNote ? null : (ratingNote ?? this.ratingNote),
      experienceDate: experienceDate ?? this.experienceDate,
      pictures: pictures ?? this.pictures,
    );
  }
}
