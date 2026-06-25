import 'package:flutter/material.dart';
import '../models/diary_manager.dart';
import '../models/diary.dart';
import '../models/custom_entry.dart';
import '../models/custom_entry_manager.dart';
import '../models/collection_template.dart';
import '../models/review.dart';
import '../models/review_manager.dart';
import '../models/collection_grid_item.dart';
import '../services/diary_lock_service.dart';
import '../services/backup_settings_service.dart';
import '../services/collection_template_service.dart';
import '../utils/diary_unlock_helper.dart';
import '../widgets/collection_list_tile.dart';
import 'add_custom_entry_screen.dart';
import 'diary_detail_screen.dart';
import 'review_detail_screen.dart';

class CollectionsListScreen extends StatefulWidget {
  const CollectionsListScreen({super.key});

  @override
  State<CollectionsListScreen> createState() => CollectionsListScreenState();
}

class CollectionsListScreenState extends State<CollectionsListScreen> {
  final DiaryManager _diaryManager = DiaryManager();
  final ReviewManager _reviewManager = ReviewManager();
  final CustomEntryManager _customEntryManager = CustomEntryManager();
  final DiaryLockService _lockService = DiaryLockService();
  final BackupSettingsService _backupSettings = BackupSettingsService();
  final CollectionTemplateService _templateService = CollectionTemplateService();
  late Future<List<CollectionGridItem>> _itemsFuture;
  final Map<String, CollectionTemplate> _templatesById = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _itemsFuture = _fetchItems();
  }

  Future<void> _loadTemplates() async {
    final templates = await _templateService.getAll();
    _templatesById
      ..clear()
      ..addEntries(templates.map((item) => MapEntry(item.id, item)));
  }

  void refresh() {
    setState(() {
      _loadData();
    });
  }

  Future<List<CollectionGridItem>> _fetchItems() async {
    await _loadTemplates();
    final results = await Future.wait([
      _diaryManager.diaries,
      _reviewManager.reviews,
      _customEntryManager.getAll(),
    ]);
    final customEntries = results[2] as List<CustomEntry>;
    final customItems = customEntries.map((entry) {
      final template = _templatesById[entry.templateId];
      return CollectionGridItem.fromCustomEntry(
        entry,
        templateName: template?.name ?? '自訂模板',
        templateIcon: template?.icon ?? Icons.note_outlined,
      );
    }).toList();
    return CollectionGridItem.mergeAndSort(
      results[0] as List<Diary>,
      results[1] as List<Review>,
      customItems,
    );
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

  Future<void> _onItemTap(CollectionGridItem item) async {
    switch (item.kind) {
      case CollectionGridKind.diary:
        final diary = item.diary!;
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
      case CollectionGridKind.review:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ReviewDetailScreen(review: item.review!),
          ),
        );
      case CollectionGridKind.custom:
        final entry = item.customEntry!;
        final template = _templatesById[entry.templateId];
        if (template == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('找不到對應模板')),
            );
          }
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddCustomEntryScreen(
              template: template,
              entry: entry,
            ),
          ),
        );
    }

    if (mounted) {
      setState(_loadData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CollectionGridItem>>(
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
              '還沒有內容，到 Collections 新增吧！',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final items = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return CollectionListTile(
              item: items[index],
              onTap: () => _onItemTap(items[index]),
            );
          },
        );
      },
    );
  }
}
