import 'dart:io';
import 'package:flutter/material.dart';
import '../models/diary_manager.dart';
import '../models/diary.dart';
import '../widgets/expandable_fab.dart';
import 'add_diary_screen.dart';
import 'diary_detail_screen.dart';
import 'placeholder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DiaryManager _diaryManager = DiaryManager();
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
                  childAspectRatio: 1, // This ensures square items
                ),
                itemCount: diaries.length,
                itemBuilder: (context, index) {
                  final diary = diaries[index];
                  return GestureDetector(
                    onTap: () => _viewDiaryDetail(diary),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        image: diary.pictures.isNotEmpty
                            ? DecorationImage(
                                image: diary.pictures.first.isLocalFile
                                    ? FileImage(File(diary.pictures.first.pictureUrl))
                                    : NetworkImage(diary.pictures.first.pictureUrl) as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: diary.pictures.isNotEmpty
                          ? Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          : Center(
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
                    ),
                  );
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDiaryScreen()),
    );

    setState(() {
      _loadDiaries();
    });
  }

  void _addTodo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlaceholderScreen(title: 'Todo')),
    );
  }

  void _addRecipe() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlaceholderScreen(title: '食譜')),
    );
  }

  void _viewDiaryDetail(Diary diary) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DiaryDetailScreen(diary: diary)),
    );

    // 重新加載日記列表
    setState(() {
      _loadDiaries();
    });
  }
}
