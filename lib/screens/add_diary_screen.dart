import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/diary.dart';
import '../models/picture.dart';
import '../models/diary_date.dart';
import '../models/mood.dart';
import '../models/database_helper.dart';
import 'package:uuid/uuid.dart';

class AddDiaryScreen extends StatefulWidget {
  final Diary? diary;

  const AddDiaryScreen({super.key, this.diary});

  @override
  State<AddDiaryScreen> createState() => _AddDiaryScreenState();
}

class _AddDiaryScreenState extends State<AddDiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  Mood? _selectedMood;
  final _captionController = TextEditingController();
  final _moodReasonController = TextEditingController();

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
      _locationController.text = widget.diary!.location ?? '';
      _selectedMood = widget.diary!.mood;
      _moodReasonController.text = widget.diary!.mood?.why ?? '';
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
    _locationController.dispose();
    _captionController.dispose();
    _moodReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.diary == null ? '新增日記' : '編輯日記'),
        actions: [
          TextButton(
            onPressed: _saveDiary,
            child: const Text(
              '儲存',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
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
              TextFormField(
                controller: _contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '寫下今天的心情和發生的事...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入日記內容';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // 圖片區塊
              const Text('圖片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 已選擇的圖片列表
              if (_selectedImageFiles.isNotEmpty) ...[
                SizedBox(
                  height: 120, // 改為 120，與圖片高度一致
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImageFiles.length + 1, // +1 為添加按鈕
                    itemBuilder: (context, index) {
                      if (index == _selectedImageFiles.length) {
                        // 添加按鈕
                        return Container(
                          width: 120,
                          height: 120,
                          margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade50,
                            ),
                            child: InkWell(
                              onTap: _showImageSourceDialog,
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
                          width: 120,
                          margin: const EdgeInsets.only(left: 8),
                          child: Stack(
                            children: [
                              // 圖片
                              Container(
                                width: 120,
                                height: 120,
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
                ),
              ] else ...[
                // 沒有圖片時的添加按鈕
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(8),
                      
                    ),
                  child: InkWell(
                    onTap: _showImageSourceDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '點擊添加圖片',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 地點
              const Text('地點', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  hintText: '你在哪裡寫這篇日記？',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              // 心情
              const Text('心情', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<Mood>(
                value: _selectedMood,
                decoration: const InputDecoration(
                  hintText: '選擇你的心情',
                  border: OutlineInputBorder(),
                ),
                items: Mood.allMoods.map((mood) {
                  // 如果當前選擇的心情有原因，則為下拉選項也加上相同的原因
                  final moodWithReason = _selectedMood != null && _selectedMood!.value == mood.value
                      ? mood.withReason(_selectedMood!.why)
                      : mood;
                  return DropdownMenuItem<Mood>(
                    value: moodWithReason,
                    child: Row(
                      children: [
                        Text(mood.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(mood.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (Mood? newMood) {
                  setState(() {
                    _selectedMood = newMood;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _moodReasonController,
                decoration: const InputDecoration(
                  hintText: '為什麼有這種心情？（可選）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) {
                  setState(() {
                    if (_selectedMood != null) {
                      _selectedMood = _selectedMood!.copyWith(why: value.isEmpty ? null : value);
                    }
                  });
                },
              ),

              const SizedBox(height: 32),

              // 儲存按鈕
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveDiary,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('儲存日記', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          final file = File(pickedFile.path);
          _selectedImageFiles.add(file);
          _pictures.add(Picture.fromFile(pickedFile.path));
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

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('選擇圖片來源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera),
                title: const Text('相機'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('相簿'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
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
            location: _locationController.text.isEmpty ? null : _locationController.text,
            mood: _selectedMood,
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
            location: _locationController.text.isEmpty ? null : _locationController.text,
            mood: _selectedMood,
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
}
