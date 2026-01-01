import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/diary.dart';
import '../models/picture.dart';
import '../models/diary_date.dart';
import '../models/database_helper.dart';
import 'package:uuid/uuid.dart';
import 'content_edit_screen.dart';

class AddDiaryScreen extends StatefulWidget {
  final Diary? diary;

  const AddDiaryScreen({super.key, this.diary});

  @override
  State<AddDiaryScreen> createState() => _AddDiaryScreenState();
}

class _AddDiaryScreenState extends State<AddDiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _captionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  List<Picture> _pictures = []; // 改為圖片列表
  List<File> _selectedImageFiles = []; // 改為圖片檔案列表

  final ImagePicker _picker = ImagePicker();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    if (widget.diary != null) {
      _selectedDate = widget.diary!.date.dateTime;
      _contentController.text = widget.diary!.content;
      _pictures = List.from(widget.diary!.pictures); // 複製圖片列表
      // 處理本地檔案
      for (var picture in widget.diary!.pictures) {
        if (picture.isLocalFile) {
          _selectedImageFiles.add(File(picture.pictureUrl));
        }
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.diary == null ? '新增日記' : '編輯日記'),
        backgroundColor: Colors.purple.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期選擇
              const Text('日期', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 內容
              const Text('內容 *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _editContent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minHeight: 100),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 60, // 约3行文本的高度
                              ),
                              child: Text(
                                _contentController.text.isEmpty
                                    ? '寫下今天的心情和發生的事...'
                                    : _contentController.text,
                                style: TextStyle(
                                  color: _contentController.text.isEmpty
                                      ? Colors.grey
                                      : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Icon(Icons.edit, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 圖片區塊
              const Text('圖片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 已選擇的圖片列表
              if (_selectedImageFiles.isNotEmpty) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 每行最多3個
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1, // 正方形比例
                  ),
                  itemCount: _selectedImageFiles.length + 1, // +1 為添加按鈕
                  itemBuilder: (context, index) {
                    if (index == _selectedImageFiles.length) {
                      // 添加按鈕
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () => _pickImages(ImageSource.gallery),
                          borderRadius: BorderRadius.circular(8),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 32,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      // 圖片項目
                      final file = _selectedImageFiles[index];
                      final picture = _pictures[index];

                      return Container(
                        child: Stack(
                          children: [
                            // 圖片
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(file),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // 刪除按鈕
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeImage(index),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // 說明文字（如果有的話）
                            if (picture.caption != null && picture.caption!.isNotEmpty)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    picture.caption!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ] else ...[
                // 沒有圖片時的添加按鈕
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(8),
                      
                    ),
                  child: InkWell(
                    onTap: () => _pickImages(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 32,
                          color: Colors.grey,
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),



            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveDiary,
        child: const Icon(Icons.save),
        tooltip: '儲存日記',
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickImages(ImageSource source) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (final pickedFile in pickedFiles) {
            final file = File(pickedFile.path);
            _selectedImageFiles.add(file);
            _pictures.add(Picture.fromFile(pickedFile.path));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選擇圖片失敗: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImageFiles.removeAt(index);
      _pictures.removeAt(index);
    });
  }


  Future<void> _editContent() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ContentEditScreen(
          initialContent: _contentController.text,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _contentController.text = result;
      });
    }
  }

  Future<void> _saveDiary() async {
    if (_formKey.currentState!.validate()) {
      final now = DateTime.now();

      try {
        if (widget.diary != null) {
          // 編輯模式：更新現有的日記
          final updatedDiary = Diary(
            id: widget.diary!.id,
            createTime: widget.diary!.createTime,
            updateTime: now,
            date: DiaryDate.fromDateTime(_selectedDate),
            content: _contentController.text,
            pictures: _pictures,
          );
          await _databaseHelper.updateDiary(updatedDiary);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('日記更新成功！')),
            );
          }
        } else {
          // 新增模式：創建新的日記
          final uuid = const Uuid();
          final diary = Diary(
            id: uuid.v4(),
            createTime: now,
            updateTime: now,
            date: DiaryDate.fromDateTime(_selectedDate),
            content: _contentController.text,
            pictures: _pictures,
          );
          await _databaseHelper.insertDiary(diary);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('日記儲存成功！')),
            );
          }
        }
        // 保存成功後返回上一頁
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('儲存失敗: $e')),
          );
        }
      }
    }
  }

  bool _isContentOverflowing(String text) {
    if (text.isEmpty) return false;

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 32 - 24); // 减去padding和icon宽度

    // 检查文本高度是否超过约3行的高度 (60像素)
    return textPainter.height > 60;
  }
}
