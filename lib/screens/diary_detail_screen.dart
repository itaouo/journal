import 'package:flutter/material.dart';
import 'dart:io';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../models/diary.dart';
import '../models/picture.dart';
import 'add_diary_screen.dart';

class DiaryDetailScreen extends StatefulWidget {
  final Diary diary;

  const DiaryDetailScreen({super.key, required this.diary});

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.diary.date.toShortWeekdayString()}',
        ),
        backgroundColor: Colors.purple.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 圖片 - 移至最上方
            if (widget.diary.pictures.isNotEmpty) ...[
              // 使用 PageView 顯示圖片
              SizedBox(
                height: MediaQuery.of(context).size.width - 40,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.diary.pictures.length,
                      itemBuilder: (context, index) {
                        final picture = widget.diary.pictures[index];
                        return Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              // 正方形圖片容器
                              SizedBox(
                                width: MediaQuery.of(context).size.width - 8, // 減去 margin
                                height: MediaQuery.of(context).size.width - 40,
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
                    // smooth_page_indicator 放置在右下角 - 只有在有多張圖片時才顯示
                    if (widget.diary.pictures.length > 1) Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SmoothPageIndicator(
                          controller: _pageController,
                          count: widget.diary.pictures.length,
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
            // 內容
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50, // 更改為淺紫色背景
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // 內容文字
                  Text(
                    widget.diary.content,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  // 更新時間 - 右下角
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Text(
                      _formatRelativeTime(widget.diary.updateTime),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

            // 心情
            if (widget.diary.mood != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50, // 與 content 相同的背景色
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.diary.mood!.fullDisplay, // 只顯示表情符號
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ],

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
        builder: (context) => AddDiaryScreen(diary: widget.diary),
      ),
    );

    // 編輯完成後返回上一頁，HomeScreen 會重新加載數據
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays >= 365) {
      return '去年';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}天前';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}小時前';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}分鐘前';
    } else {
      return '剛剛';
    }
  }
}
