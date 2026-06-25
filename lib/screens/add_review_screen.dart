import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../models/review.dart';
import '../models/review_type.dart';
import '../models/review_manager.dart';
import '../models/diary_date.dart';
import '../models/picture.dart';
import '../widgets/rating_input.dart';
import '../theme/app_theme.dart';
import 'content_edit_screen.dart';

class AddReviewScreen extends StatefulWidget {
  final Review? review;

  const AddReviewScreen({super.key, this.review});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _keyQuotesController = TextEditingController();
  final _thoughtsController = TextEditingController();

  ReviewType _reviewType = ReviewType.movie;
  DateTime _experienceDate = DateTime.now();
  int? _rating;
  String? _ratingNote;
  bool _isSaving = false;
  List<Picture> _pictures = [];

  final ImagePicker _picker = ImagePicker();
  final ReviewManager _reviewManager = ReviewManager();

  @override
  void initState() {
    super.initState();
    if (widget.review != null) {
      final review = widget.review!;
      _reviewType = review.reviewType;
      _titleController.text = review.title;
      _summaryController.text = review.summary;
      _keyQuotesController.text = review.keyQuotes;
      _thoughtsController.text = review.thoughts;
      _experienceDate = review.experienceDate.dateTime;
      _rating = review.rating;
      _ratingNote = review.ratingNote;
      _pictures = List.from(review.pictures);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _keyQuotesController.dispose();
    _thoughtsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        backgroundColor: context.journalColors.cardBackground,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('類型'),
              DropdownButtonFormField<ReviewType>(
                value: _reviewType,
                decoration: _inputDecoration(context),
                items: ReviewType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(type.icon, size: 20),
                            const SizedBox(width: 8),
                            Text(type.displayName),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _reviewType = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              _sectionLabel('標題 *'),
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration(context, hint: '作品名稱'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '請輸入標題';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _sectionLabel('觀看 / 閱讀日期'),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: _boxDecoration(context),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 8),
                      Text(
                        '${_experienceDate.year}-${_experienceDate.month.toString().padLeft(2, '0')}-${_experienceDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel('圖片'),
              const SizedBox(height: 8),
              if (_pictures.isNotEmpty) ...[
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: _pictures.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _pictures.length) {
                      return InkWell(
                        onTap: () => _pickImages(ImageSource.gallery),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: context.journalColors.inputBorder,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }
                    final picture = _pictures[index];
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: picture.isLocalFile
                                  ? FileImage(File(picture.pictureUrl))
                                  : NetworkImage(picture.pictureUrl)
                                      as ImageProvider,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
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
                      ],
                    );
                  },
                ),
              ] else ...[
                Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: InkWell(
                      onTap: () => _pickImages(ImageSource.gallery),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: context.journalColors.inputBorder,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.add_photo_alternate,
                          size: 32,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _sectionLabel('劇情概要'),
              _textSection(
                text: _summaryController.text,
                hint: '簡述劇情或內容...',
                onTap: () => _editField(
                  _summaryController,
                  hint: '簡述劇情或內容...',
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel('核心金句'),
              _textSection(
                text: _keyQuotesController.text,
                hint: '印象深刻的台詞或段落...',
                onTap: () => _editField(
                  _keyQuotesController,
                  hint: '印象深刻的台詞或段落...',
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel('心得'),
              _textSection(
                text: _thoughtsController.text,
                hint: '寫下你的觀後或讀後感想...',
                onTap: () => _editField(
                  _thoughtsController,
                  hint: '寫下你的觀後或讀後感想...',
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel('推薦指數'),
              RatingInput(
                rating: _rating,
                ratingNote: _ratingNote,
                onRatingChanged: (value) => setState(() => _rating = value),
                onRatingNoteChanged: (value) {
                  _ratingNote = value.isEmpty ? null : value;
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _saveReview,
        tooltip: '儲存 Review',
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, {String? hint}) {
    final borderColor = context.journalColors.inputBorder;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: context.journalColors.cardBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration(BuildContext context) {
    return BoxDecoration(
      color: context.journalColors.cardBackground,
      border: Border.all(color: context.journalColors.inputBorder),
      borderRadius: BorderRadius.circular(8),
    );
  }

  Widget _textSection({
    required String text,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: _boxDecoration(context),
        constraints: const BoxConstraints(minHeight: 80),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                text.isEmpty ? hint : text,
                style: TextStyle(
                  color: text.isEmpty ? Colors.grey : Colors.black,
                  fontSize: 16,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.edit, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _experienceDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _experienceDate) {
      setState(() => _experienceDate = picked);
    }
  }

  Future<void> _editField(
    TextEditingController controller, {
    required String hint,
  }) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ContentEditScreen(
          initialContent: controller.text,
          hintText: hint,
        ),
      ),
    );
    if (result != null) {
      setState(() => controller.text = result);
    }
  }

  Future<void> _pickImages(ImageSource source) async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (final pickedFile in pickedFiles) {
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
    setState(() => _pictures.removeAt(index));
  }

  Future<void> _saveReview() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    setState(() => _isSaving = true);
    final now = DateTime.now();

    try {
      if (widget.review != null) {
        final updated = Review(
          id: widget.review!.id,
          createTime: widget.review!.createTime,
          updateTime: now,
          reviewType: _reviewType,
          title: _titleController.text.trim(),
          summary: _summaryController.text,
          keyQuotes: _keyQuotesController.text,
          thoughts: _thoughtsController.text,
          rating: _rating,
          ratingNote: _ratingNote,
          experienceDate: DiaryDate.fromDateTime(_experienceDate),
          pictures: _pictures,
        );
        await _reviewManager.updateReview(updated);
      } else {
        final review = Review(
          id: const Uuid().v4(),
          createTime: now,
          updateTime: now,
          reviewType: _reviewType,
          title: _titleController.text.trim(),
          summary: _summaryController.text,
          keyQuotes: _keyQuotesController.text,
          thoughts: _thoughtsController.text,
          rating: _rating,
          ratingNote: _ratingNote,
          experienceDate: DiaryDate.fromDateTime(_experienceDate),
          pictures: _pictures,
        );
        await _reviewManager.addReview(review);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review 已儲存')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
