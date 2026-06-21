import 'package:flutter/material.dart';
import 'dart:io';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../models/diary.dart';
import '../models/diary_manager.dart';
import '../services/diary_lock_service.dart';
import '../widgets/pin_entry_dialog.dart';
import '../widgets/pin_setup_dialog.dart';
import 'add_diary_screen.dart';

class DiaryDetailScreen extends StatefulWidget {
  final Diary diary;

  const DiaryDetailScreen({super.key, required this.diary});

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  final PageController _pageController = PageController();
  final DiaryManager _diaryManager = DiaryManager();
  final DiaryLockService _lockService = DiaryLockService();
  late bool _isLocked;
  bool _isUpdatingLock = false;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.diary.isLocked;
  }

  @override
  void dispose() {
    _lockService.resetSession();
    _pageController.dispose();
    super.dispose();
  }

  Diary get _currentDiary => Diary(
        id: widget.diary.id,
        createTime: widget.diary.createTime,
        updateTime: widget.diary.updateTime,
        isDeleted: widget.diary.isDeleted,
        date: widget.diary.date,
        content: widget.diary.content,
        pictures: widget.diary.pictures,
        isLocked: _isLocked,
      );

  Future<void> _toggleLock() async {
    if (_isUpdatingLock) return;

    if (_isLocked) {
      final pin = await showPinEntryDialog(
        context,
        title: '輸入 PIN',
        subtitle: '解除上鎖需要驗證 PIN',
      );
      if (pin == null) return;
      if (!await _lockService.verifyPin(pin)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN 錯誤')),
          );
        }
        return;
      }
    } else {
      if (!await _lockService.hasPin()) {
        final setupPin = await showPinSetupDialog(
          context,
          title: '設定 PIN',
          subtitle: '首次上鎖需設定本機 PIN',
        );
        if (setupPin == null) return;
        await _lockService.setPin(setupPin);
      } else if (!_lockService.hasSessionPin) {
        final pin = await showPinEntryDialog(
          context,
          title: '輸入 PIN',
          subtitle: '上鎖需要驗證 PIN',
        );
        if (pin == null) return;
        if (!await _lockService.verifyPin(pin)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PIN 錯誤')),
            );
          }
          return;
        }
      }
    }

    setState(() => _isUpdatingLock = true);
    try {
      final newLocked = !_isLocked;
      await _diaryManager.setDiaryLocked(widget.diary.id, newLocked);
      if (mounted) {
        setState(() {
          _isLocked = newLocked;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newLocked ? '日記已上鎖' : '日記已解除上鎖'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新上鎖狀態失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLock = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.diary.date.toShortWeekdayString(),
        ),
        backgroundColor: Colors.purple.shade50,
        actions: [
          IconButton(
            onPressed: _isUpdatingLock ? null : _toggleLock,
            tooltip: _isLocked ? '解除上鎖' : '上鎖',
            icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.diary.pictures.isNotEmpty) ...[
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
                              SizedBox(
                                width: MediaQuery.of(context).size.width - 8,
                                height: MediaQuery.of(context).size.width - 40,
                                child: Builder(
                                  builder: (context) {
                                    final displayPicture =
                                        picture.withDisplayFallback();
                                    if (!displayPicture.isValid()) {
                                      return Container(
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
                                      );
                                    }
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: displayPicture.isLocalFile
                                              ? FileImage(File(
                                                  displayPicture.pictureUrl))
                                              : NetworkImage(
                                                      displayPicture.pictureUrl)
                                                  as ImageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
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
                    if (widget.diary.pictures.length > 1)
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  Text(
                    widget.diary.content,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editDiary(context),
        tooltip: '編輯日記',
        child: const Icon(Icons.edit),
      ),
    );
  }

  void _editDiary(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDiaryScreen(diary: _currentDiary),
      ),
    );

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
