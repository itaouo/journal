import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/collection_template.dart';
import '../models/custom_entry.dart';
import '../models/custom_entry_manager.dart';
import '../services/backup_settings_service.dart';
import '../services/diary_lock_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_entry_dialog.dart';
import '../widgets/pin_setup_dialog.dart';
import '../widgets/rating_input.dart';
import 'content_edit_screen.dart';

class AddCustomEntryScreen extends StatefulWidget {
  const AddCustomEntryScreen({
    super.key,
    required this.template,
    this.entry,
  });

  final CollectionTemplate template;
  final CustomEntry? entry;

  @override
  State<AddCustomEntryScreen> createState() => _AddCustomEntryScreenState();
}

class _AddCustomEntryScreenState extends State<AddCustomEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _entryManager = CustomEntryManager();
  final _lockService = DiaryLockService();
  final _backupSettings = BackupSettingsService();
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  final Map<String, String> _textValues = {};
  final Map<String, DateTime> _dateValues = {};
  final Map<String, List<String>> _imageValues = {};
  final Map<String, int?> _ratingValues = {};
  final Map<String, String?> _ratingNotes = {};

  bool _isSaving = false;
  bool _isLocked = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.entry?.isLocked ?? false;
    final values = widget.entry?.fieldValues ?? const <String, dynamic>{};
    for (final field in widget.template.fields) {
      switch (field.type) {
        case TemplateFieldType.text:
        case TemplateFieldType.largeText:
          _textValues[field.id] = (values[field.id] as String?) ?? '';
        case TemplateFieldType.date:
          final raw = values[field.id] as String?;
          _dateValues[field.id] =
              DateTime.tryParse(raw ?? '') ?? DateTime.now();
        case TemplateFieldType.image:
          final raw = values[field.id];
          if (raw is List) {
            _imageValues[field.id] = raw.map((e) => e.toString()).toList();
          } else {
            _imageValues[field.id] = [];
          }
        case TemplateFieldType.rating:
          _ratingValues[field.id] = values[field.id] as int?;
          _ratingNotes[field.id] = values['${field.id}__note'] as String?;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name),
        actions: [
          if (widget.template.isLockable)
            IconButton(
              onPressed: _toggleLock,
              tooltip: _isLocked ? '解除上鎖' : '上鎖',
              icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final field in widget.template.fields) ...[
              _fieldLabel(field.label),
              _buildField(field),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isSaving ? null : _save,
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.trim().isEmpty ? '未命名欄位' : label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildField(TemplateField field) {
    switch (field.type) {
      case TemplateFieldType.text:
        return TextFormField(
          initialValue: _textValues[field.id] ?? '',
          decoration: InputDecoration(hintText: field.hint),
          validator: field.isRequired
              ? (value) {
                  if ((value ?? '').trim().isEmpty) return '此欄位必填';
                  return null;
                }
              : null,
          onChanged: (value) => _textValues[field.id] = value,
        );
      case TemplateFieldType.largeText:
        final text = _textValues[field.id] ?? '';
        return InkWell(
          onTap: () => _editLargeText(field),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            constraints: const BoxConstraints(minHeight: 84),
            decoration: BoxDecoration(
              color: context.journalColors.cardBackground,
              border: Border.all(color: context.journalColors.inputBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    text.isEmpty ? field.hint : text,
                    style: TextStyle(
                      color: text.isEmpty ? Colors.grey : Colors.black,
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
      case TemplateFieldType.date:
        final value = _dateValues[field.id] ?? DateTime.now();
        return InkWell(
          onTap: () => _pickDateTime(field),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: context.journalColors.cardBackground,
              border: Border.all(color: context.journalColors.inputBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    field.dateMode == DateFieldMode.dateOnly
                        ? _formatDate(value)
                        : _formatDateTime(value),
                  ),
                ),
              ],
            ),
          ),
        );
      case TemplateFieldType.image:
        final images = _imageValues[field.id] ?? [];
        return _buildImageField(field, images);
      case TemplateFieldType.rating:
        return RatingInput(
          rating: _ratingValues[field.id],
          ratingNote: _ratingNotes[field.id],
          onRatingChanged: (value) => setState(() => _ratingValues[field.id] = value),
          onRatingNoteChanged: (value) {
            _ratingNotes[field.id] = value.isEmpty ? null : value;
          },
        );
    }
  }

  Widget _buildImageField(TemplateField field, List<String> images) {
    if (images.isEmpty) {
      return Center(
        child: SizedBox(
          width: 120,
          height: 120,
          child: InkWell(
            onTap: () => _pickImages(field.id),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.journalColors.inputBorder),
              ),
              child: const Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length + 1,
      itemBuilder: (context, index) {
        if (index == images.length) {
          return InkWell(
            onTap: () => _pickImages(field.id),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.journalColors.inputBorder),
              ),
              child: const Icon(Icons.add_photo_alternate, size: 30, color: Colors.grey),
            ),
          );
        }
        final path = images[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: InkWell(
                onTap: () => _removeImage(field.id, index),
                child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDateTime(TemplateField field) async {
    final current = _dateValues[field.id] ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (date == null) return;

    if (field.dateMode == DateFieldMode.dateOnly) {
      setState(() {
        _dateValues[field.id] = DateTime(date.year, date.month, date.day);
      });
      return;
    }

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;

    setState(() {
      _dateValues[field.id] = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _editLargeText(TemplateField field) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ContentEditScreen(
          initialContent: _textValues[field.id] ?? '',
          hintText: field.hint,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _textValues[field.id] = result;
    });
  }

  Future<void> _pickImages(String fieldId) async {
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked.isEmpty) return;
      setState(() {
        final list = _imageValues[fieldId] ?? <String>[];
        list.addAll(picked.map((item) => item.path));
        _imageValues[fieldId] = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選擇圖片失敗: $e')),
      );
    }
  }

  void _removeImage(String fieldId, int index) {
    setState(() {
      _imageValues[fieldId]?.removeAt(index);
    });
  }

  Future<void> _toggleLock() async {
    final pinPromptMode = await _backupSettings.getLockPinPromptMode();

    if (_isLocked) {
      final pin = await showPinEntryDialog(
        context,
        title: '輸入 PIN',
        subtitle: '解除上鎖需要驗證 PIN',
      );
      if (pin == null) return;
      if (!await _lockService.verifyPin(pin, pinPromptMode: pinPromptMode)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN 錯誤')),
        );
        return;
      }
    } else {
      if (!await _lockService.hasPin()) {
        final setupPin = await showPinSetupDialog(
          context,
          title: '設定 PIN',
          subtitle: '首次上鎖需設定 PIN',
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
        if (!await _lockService.verifyPin(pin, pinPromptMode: pinPromptMode)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN 錯誤')),
          );
          return;
        }
      }
    }

    setState(() => _isLocked = !_isLocked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validateRequiredFields()) return;

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final fieldValues = <String, dynamic>{};

    for (final field in widget.template.fields) {
      switch (field.type) {
        case TemplateFieldType.text:
        case TemplateFieldType.largeText:
          fieldValues[field.id] = (_textValues[field.id] ?? '').trim();
        case TemplateFieldType.date:
          fieldValues[field.id] =
              (_dateValues[field.id] ?? now).toIso8601String();
        case TemplateFieldType.image:
          fieldValues[field.id] = List<String>.from(_imageValues[field.id] ?? []);
        case TemplateFieldType.rating:
          fieldValues[field.id] = _ratingValues[field.id];
          final note = _ratingNotes[field.id];
          if (note != null && note.trim().isNotEmpty) {
            fieldValues['${field.id}__note'] = note.trim();
          }
      }
    }

    final existing = widget.entry;
    final entry = CustomEntry(
      id: existing?.id ?? _uuid.v4(),
      createTime: existing?.createTime ?? now,
      updateTime: now,
      templateId: widget.template.id,
      isLocked: _isLocked,
      fieldValues: fieldValues,
    );

    try {
      if (_isEditing) {
        await _entryManager.update(entry);
      } else {
        await _entryManager.add(entry);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已儲存')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗: $e')),
      );
      setState(() => _isSaving = false);
    }
  }

  bool _validateRequiredFields() {
    for (final field in widget.template.fields) {
      if (!field.isRequired) continue;
      switch (field.type) {
        case TemplateFieldType.text:
        case TemplateFieldType.largeText:
          if ((_textValues[field.id] ?? '').trim().isEmpty) {
            _showRequiredFieldError(field);
            return false;
          }
        case TemplateFieldType.date:
          if (_dateValues[field.id] == null) {
            _showRequiredFieldError(field);
            return false;
          }
        case TemplateFieldType.image:
          if ((_imageValues[field.id] ?? const []).isEmpty) {
            _showRequiredFieldError(field);
            return false;
          }
        case TemplateFieldType.rating:
          if (_ratingValues[field.id] == null) {
            _showRequiredFieldError(field);
            return false;
          }
      }
    }
    return true;
  }

  void _showRequiredFieldError(TemplateField field) {
    final label = field.label.trim().isEmpty ? '未命名欄位' : field.label;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$label」為必填')),
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${_formatDate(value)} $hour:$minute';
  }
}
