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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日記本'),
        centerTitle: true,
      ),
      body: _diaryManager.diaries.isEmpty
          ? const Center(
              child: Text(
                '還沒有日記，點擊 + 按鈕新增第一篇吧！',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _diaryManager.diaries.length,
              itemBuilder: (context, index) {
                final diary = _diaryManager.diaries[index];
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewDiary,
        child: const Icon(Icons.add),
        tooltip: '新增日記',
      ),
    );
  }

  void _addNewDiary() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDiaryScreen()),
    );

    if (result != null && result is Diary) {
      setState(() {
        _diaryManager.addDiary(result);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日記儲存成功！')),
        );
      }
    }
  }

  void _viewDiaryDetail(Diary diary) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DiaryDetailScreen(diary: diary)),
    );

    if (result != null && result is Diary) {
      setState(() {
        _diaryManager.updateDiary(diary.id, result);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('日記更新成功！')),
        );
      }
    }
  }

  int min(int a, int b) => a < b ? a : b;
}
