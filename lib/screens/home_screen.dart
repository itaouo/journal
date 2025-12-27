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
    return Scaffold(
      appBar: AppBar(
        title: const Text('日記本'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Diary>>(
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
            return ListView.builder(
              itemCount: diaries.length,
              itemBuilder: (context, index) {
                final diary = diaries[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(
                      diary.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${diary.date.relativeDateString} ${diary.location ?? ""}',
                    ),
                    trailing: diary.mood != null
                        ? Text(diary.mood!.emoji, style: const TextStyle(fontSize: 20))
                        : null,
                    onTap: () => _viewDiaryDetail(diary),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewDiary,
        child: const Icon(Icons.add),
        tooltip: '新增日記',
      ),
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

  int min(int a, int b) => a < b ? a : b;
}
