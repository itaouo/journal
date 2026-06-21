import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../models/diary_manager.dart';
import '../models/diary.dart';
import '../widgets/expandable_fab.dart';
import '../services/diary_lock_service.dart';
import '../services/widget_launch_service.dart';
import '../widgets/pin_entry_dialog.dart';
import '../widgets/pin_setup_dialog.dart';
import 'diary_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DiaryManager _diaryManager = DiaryManager();
  final DiaryLockService _lockService = DiaryLockService();
  late Future<List<Diary>> _diariesFuture;

  @override
  void initState() {
    super.initState();
    _loadDiaries();
  }

  void _loadDiaries() {
    _diariesFuture = _diaryManager.diaries;
  }

  void refresh() {
    setState(() {
      _loadDiaries();
    });
  }

  ImageProvider? _pictureImageProvider(Diary diary) {
    if (diary.pictures.isEmpty) return null;
    final picture = diary.pictures.first.withDisplayFallback();
    if (!picture.isValid()) return null;
    return picture.isLocalFile
        ? FileImage(File(picture.pictureUrl))
        : NetworkImage(picture.pictureUrl);
  }

  Widget _buildDiaryTile(Diary diary) {
    final imageProvider = _pictureImageProvider(diary);
    final hasImage = imageProvider != null;

    return GestureDetector(
      onTap: () => _viewDiaryDetail(diary),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
              )
            else
              Container(color: Colors.purple.shade50),
            if (diary.isLocked && hasImage)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            if (diary.isLocked)
              Container(color: Colors.black.withOpacity(0.15)),
            if (diary.isLocked)
              Center(
                child: Icon(
                  Icons.lock,
                  size: 28,
                  color: Colors.white,
                ),
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

  Future<bool> _ensureUnlocked(Diary diary) async {
    if (!diary.isLocked || _lockService.isUnlockedForSession) {
      return true;
    }

    if (!await _lockService.hasPin()) {
      if (!mounted) return false;
      final setupPin = await showPinSetupDialog(
        context,
        title: '設定 PIN',
        subtitle: '此日記已上鎖，請先設定本機 PIN 才能開啟',
      );
      if (setupPin == null) return false;
      await _lockService.setPin(setupPin);
      _lockService.markSessionUnlocked();
      return true;
    }

    if (!mounted) return false;
    final pin = await showPinEntryDialog(
      context,
      title: '輸入 PIN',
      subtitle: '此日記已上鎖',
    );
    if (pin == null) return false;

    if (!await _lockService.verifyPin(pin)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN 錯誤')),
        );
      }
      return false;
    }

    _lockService.markSessionUnlocked();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<List<Diary>>(
          future: _diariesFuture,
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
                  '還沒有日記，點擊 + 按鈕新增第一篇吧！',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            } else {
              final diaries = snapshot.data!;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: diaries.length,
                itemBuilder: (context, index) {
                  return _buildDiaryTile(diaries[index]);
                },
              );
            }
          },
        ),
        ExpandableFab(
          items: [
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
      onDiaryChanged: () => setState(_loadDiaries),
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
      _loadDiaries();
    });
  }
}
