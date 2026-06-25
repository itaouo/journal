import 'package:flutter/material.dart';
import 'dart:io';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../models/review.dart';
import '../models/review_manager.dart';
import '../theme/app_theme.dart';
import 'add_review_screen.dart';

class ReviewDetailScreen extends StatefulWidget {
  final Review review;

  const ReviewDetailScreen({super.key, required this.review});

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  final PageController _pageController = PageController();
  final ReviewManager _reviewManager = ReviewManager();
  bool _isDeleting = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        backgroundColor: context.journalColors.cardBackground,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (review.pictures.isNotEmpty) ...[
              SizedBox(
                height: MediaQuery.of(context).size.width - 40,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: review.pictures.length,
                      itemBuilder: (context, index) {
                        final picture = review.pictures[index];
                        final displayPicture = picture.withDisplayFallback();
                        return Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width - 8,
                                height: MediaQuery.of(context).size.width - 40,
                                child: !displayPicture.isValid()
                                    ? Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          image: DecorationImage(
                                            image: displayPicture.isLocalFile
                                                ? FileImage(File(
                                                    displayPicture.pictureUrl))
                                                : NetworkImage(displayPicture
                                                        .pictureUrl)
                                                    as ImageProvider,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                              ),
                              if (picture.caption != null &&
                                  picture.caption!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  picture.caption!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    if (review.pictures.length > 1)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SmoothPageIndicator(
                            controller: _pageController,
                            count: review.pictures.length,
                            effect: ScrollingDotsEffect(
                              dotHeight: 6,
                              dotWidth: 6,
                              activeDotColor: Colors.white.withOpacity(0.8),
                              dotColor: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Chip(
                  avatar: Icon(review.reviewType.icon, size: 18),
                  label: Text(review.reviewType.displayName),
                  backgroundColor: context.journalColors.cardBackground,
                ),
                const SizedBox(width: 8),
                Text(
                  review.experienceDate.toWeekdayString(),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
            if (review.rating != null ||
                (review.ratingNote?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (review.rating != null)
                    ...List.generate(5, (index) {
                      final filled = index < review.rating!;
                      return Icon(
                        filled ? Icons.star : Icons.star_border,
                        color: filled ? Colors.amber : Colors.grey.shade400,
                        size: 24,
                      );
                    }),
                  if (review.ratingNote != null &&
                      review.ratingNote!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      review.ratingNote!,
                      style: TextStyle(
                        color: context.journalColors.sectionHeader,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (review.summary.isNotEmpty) ...[
              _section('劇情概要', review.summary),
              const SizedBox(height: 16),
            ],
            if (review.keyQuotes.isNotEmpty) ...[
              _section('核心金句', review.keyQuotes),
              const SizedBox(height: 16),
            ],
            if (review.thoughts.isNotEmpty) ...[
              _section('心得', review.thoughts),
            ],
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'edit_review',
            onPressed: () => _editReview(context),
            tooltip: '編輯 Review',
            child: const Icon(Icons.edit),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'delete_review',
            onPressed: _isDeleting ? null : _deleteReview,
            tooltip: '刪除 Review',
            child: _isDeleting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.journalColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ],
    );
  }

  Future<void> _editReview(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReviewScreen(review: widget.review),
      ),
    );
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除 Review'),
        content: const Text('確定要刪除這篇 Review 嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _reviewManager.deleteReview(widget.review);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review 已刪除')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}
