import 'dart:io';
import 'package:flutter/material.dart';
import '../models/diary_manager.dart';
import '../models/diary.dart';
import 'add_diary_screen.dart';
import 'diary_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _addNewDiary,
            child: const Icon(Icons.add),
            tooltip: '新增日記',
          ),
        ),
      ],
    );
  }

  void _addNewDiary() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDiaryScreen()),
    );

    // 重新加載日記列表
    setState(() {
      _loadDiaries();
    });
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
