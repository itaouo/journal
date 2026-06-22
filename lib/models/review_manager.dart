import 'review.dart';
import 'database_helper.dart';

class ReviewManager {
  static final ReviewManager _instance = ReviewManager._internal();
  final DatabaseHelper _db = DatabaseHelper();

  factory ReviewManager() {
    return _instance;
  }

  ReviewManager._internal();

  Future<List<Review>> get reviews async {
    return _db.getAllReviews();
  }

  Future<Review?> getReviewById(String id) async {
    return _db.getReview(id);
  }

  Future<void> addReview(Review review) async {
    await _db.insertReview(review);
  }

  Future<void> updateReview(Review review) async {
    await _db.updateReview(review);
  }

  Future<void> deleteReview(Review review) async {
    await _db.deleteReview(review.id);
  }
}
