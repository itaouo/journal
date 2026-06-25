import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../models/diary_manager.dart';
import '../models/diary.dart';
import '../models/review.dart';
import '../models/review_manager.dart';
import '../models/collection_grid_item.dart';
import '../models/picture.dart';
import '../widgets/expandable_fab.dart';
import '../services/diary_lock_service.dart';
import '../services/backup_settings_service.dart';
import '../services/widget_launch_service.dart';
import '../utils/diary_unlock_helper.dart';
import 'diary_detail_screen.dart';
import 'review_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DiaryManager _diaryManager = DiaryManager();
  final ReviewManager _reviewManager = ReviewManager();
  final DiaryLockService _lockService = DiaryLockService();
  final BackupSettingsService _backupSettings = BackupSettingsService();
  late Future<List<CollectionGridItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _itemsFuture = _fetchItems();
  }

  Future<List<CollectionGridItem>> _fetchItems() async {
    final results = await Future.wait([
      _diaryManager.diaries,
      _reviewManager.reviews,
    ]);
    return CollectionGridItem.mergeAndSort(
      results[0] as List<Diary>,
      results[1] as List<Review>,
    );
  }

  void refresh() {
    setState(() {
      _loadData();
    });
  }

  ImageProvider? _pictureImageProvider(Picture picture) {
    final display = picture.withDisplayFallback();
    if (!display.isValid()) return null;
    return display.isLocalFile
        ? FileImage(File(display.pictureUrl))
        : NetworkImage(display.pictureUrl);
  }

  ImageProvider? _diaryImageProvider(Diary diary) {
    if (diary.pictures.isEmpty) return null;
    return _pictureImageProvider(diary.pictures.first);
  }

  ImageProvider? _reviewImageProvider(Review review) {
    if (review.pictures.isEmpty) return null;
    return _pictureImageProvider(review.pictures.first);
  }

  Widget _buildDiaryTile(Diary diary) {
    final imageProvider = _diaryImageProvider(diary);
    final hasImage = imageProvider != null;

    return GestureDetector(
      onTap: () => _viewDiaryDetail(diary),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image(image: imageProvider, fit: BoxFit.cover)
            else
              Container(color: Colors.purple.shade50),
            if (diary.isLocked && hasImage)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Image(image: imageProvider, fit: BoxFit.cover),
              ),
            if (diary.isLocked)
              Container(color: Colors.black.withOpacity(0.15)),
            if (diary.isLocked)
              const Center(
                child: Icon(Icons.lock, size: 28, color: Colors.white),
              ),
            if (hasImage || diary.isLocked)
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    diary.date.shortDateString,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Center(
                child: Text(
                  diary.date.shortDateString,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewBottomBadge(Review review) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              review.reviewType.icon,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              review.experienceDate.shortDateString,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTile(Review review) {
    final imageProvider = _reviewImageProvider(review);
    final hasImage = imageProvider != null;

    return GestureDetector(
      onTap: () => _viewReviewDetail(review),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image(image: imageProvider, fit: BoxFit.cover)
            else
              Container(color: Colors.purple.shade50),
            if (hasImage)
              _buildReviewBottomBadge(review)
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    review.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (!hasImage) _buildReviewBottomBadge(review),
          ],
        ),
      ),
    );
  }

  Widget _buildGridTile(CollectionGridItem item) {
    switch (item.kind) {
      case CollectionGridKind.diary:
        return _buildDiaryTile(item.diary!);
      case CollectionGridKind.review:
        return _buildReviewTile(item.review!);
    }
  }

  Future<bool> _ensureUnlocked(Diary diary) async {
    final pinPromptMode = await _backupSettings.getLockPinPromptMode();
    if (!mounted) return false;
    return ensureLockedDiaryUnlocked(
      context,
      diary: diary,
      lockService: _lockService,
      pinPromptMode: pinPromptMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<CollectionGridItem>>(
          future: _itemsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Text('載入失敗: ${snapshot.error}'),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  '還沒有內容，點擊 + 按鈕新增吧！',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            } else {
              final items = snapshot.data!;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildGridTile(items[index]);
                },
              );
            }
          },
        ),
        ExpandableFab(
          items: [
            ExpandableFabItem(
              icon: Icons.rate_review_outlined,
              label: 'Review',
              onTap: _addReview,
            ),
            ExpandableFabItem(
              icon: Icons.check_box_outlined,
              label: 'todo',
              onTap: _addTodo,
            ),
            ExpandableFabItem(
              icon: Icons.book_outlined,
              label: '日記',
              onTap: _addNewDiary,
            ),
            ExpandableFabItem(
              icon: Icons.restaurant_menu_outlined,
              label: '食譜',
              onTap: _addRecipe,
            ),
          ],
        ),
      ],
    );
  }

  void _addNewDiary() async {
    await WidgetLaunchService.instance.navigateToQuickAdd(
      context,
      QuickAddAction.diary,
      onDiaryChanged: () => setState(_loadData),
    );
  }

  void _addReview() async {
    await WidgetLaunchService.instance.navigateToQuickAdd(
      context,
      QuickAddAction.review,
      onDiaryChanged: () => setState(_loadData),
    );
  }

  void _addTodo() {
    WidgetLaunchService.instance.navigateToQuickAdd(
      context,
      QuickAddAction.todo,
    );
  }

  void _addRecipe() {
    WidgetLaunchService.instance.navigateToQuickAdd(
      context,
      QuickAddAction.recipe,
    );
  }

  void _viewDiaryDetail(Diary diary) async {
    if (!await _ensureUnlocked(diary)) return;

    if (!mounted) return;

    Diary? loadedDiary = diary;
    if (diary.isLocked) {
      loadedDiary = await _diaryManager.getDiaryById(diary.id);
    }
    if (loadedDiary == null || !mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryDetailScreen(diary: loadedDiary!),
      ),
    );

    setState(() {
      _loadData();
    });
  }

  void _viewReviewDetail(Review review) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewDetailScreen(review: review),
      ),
    );

    setState(() {
      _loadData();
    });
  }
}
