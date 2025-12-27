import 'package:flutter/material.dart';
import 'dart:io';
import '../models/diary.dart';
import '../models/picture.dart';
import 'add_diary_screen.dart';

class DiaryDetailScreen extends StatelessWidget {
  final Diary diary;

  const DiaryDetailScreen({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${diary.date.toShortWeekdayString()}',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期和心情
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Text(
                //   '日期: ${diary.date.toWeekdayString()}',
                //   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                // ),
                if (diary.mood != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      diary.mood!.fullDescription,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // 地點
            if (diary.location != null && diary.location!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    diary.location!,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 內容
            const Text(
              '內容',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50, // 更改為淺紫色背景
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                diary.content,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),

            const SizedBox(height: 24),

            // 圖片
            if (diary.pictures.isNotEmpty) ...[
              const Text(
                '圖片',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: diary.pictures.length,
                  itemBuilder: (context, index) {
                    final picture = diary.pictures[index];
                    return Container(
                      width: 200,
                      margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: picture.isLocalFile
                                      ? FileImage(File(picture.pictureUrl))
                                      : NetworkImage(picture.pictureUrl) as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          if (picture.caption != null && picture.caption!.isNotEmpty) ...[
                            const SizedBox(height: 4),
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
              ),
            ],

            const SizedBox(height: 24),

            // 創建和更新時間
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '創建時間: ${_formatDateTime(diary.createTime)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    '更新時間: ${_formatDateTime(diary.updateTime)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editDiary(context),
        child: const Icon(Icons.edit),
        tooltip: '編輯日記',
      ),
    );
  }

  void _editDiary(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDiaryScreen(diary: diary),
      ),
    );

    // 編輯完成後返回上一頁，HomeScreen 會重新加載數據
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
