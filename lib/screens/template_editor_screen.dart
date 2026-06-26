import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../models/collection_template.dart';
import '../utils/template_icons.dart';
import '../models/custom_entry.dart';
import '../models/custom_entry_manager.dart';
import '../services/collection_template_service.dart';
import '../theme/app_theme.dart';
import '../widgets/unsaved_changes_dialog.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({
    super.key,
    this.template,
    CollectionTemplateService? service,
  }) : _service = service;

  final CollectionTemplate? template;
  final CollectionTemplateService? _service;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _uuid = const Uuid();

  late final CollectionTemplateService _service;
  final CustomEntryManager _customEntryManager = CustomEntryManager();
  late bool _isReadOnly;
  bool _isLockable = false;
  bool _iconPickerExpanded = false;
  bool _isSaving = false;
  int _selectedIconCodePoint = CollectionTemplate.defaultIconCodePoint;
  List<TemplateField> _fields = [];
  late final String _initialSnapshot;

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? CollectionTemplateService();
    _isReadOnly = widget.template?.isBuiltIn ?? false;
    _nameController.text = widget.template?.name ?? '';
    _isLockable = widget.template?.isLockable ?? false;
    _selectedIconCodePoint =
        widget.template?.iconCodePoint ?? CollectionTemplate.defaultIconCodePoint;
    _fields = List<TemplateField>.from(widget.template?.fields ?? []);
    _initialSnapshot = _encodeSnapshot();
  }

  bool get _hasUnsavedChanges =>
      !_isReadOnly && _encodeSnapshot() != _initialSnapshot;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleUnsavedChangesPop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isReadOnly ? '查看模板' : '模板編輯'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('基本設定'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              readOnly: _isReadOnly,
              decoration: const InputDecoration(
                labelText: '模板名稱',
                hintText: '例如：旅行日記',
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return '請輸入模板名稱';
                return null;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('可上鎖'),
              subtitle: const Text('建立內容時可選擇上鎖'),
              value: _isLockable,
              onChanged: _isReadOnly
                  ? null
                  : (value) => setState(() => _isLockable = value),
            ),
            const SizedBox(height: 12),
            _buildIconPicker(context),
            const SizedBox(height: 16),
            _sectionTitle('欄位清單'),
            const SizedBox(height: 8),
            if (_fields.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.journalColors.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.journalColors.inputBorder),
                ),
                child: const Text('尚未新增欄位'),
              ),
            if (_fields.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: _isReadOnly ? (_, __) {} : _onReorder,
                itemCount: _fields.length,
                itemBuilder: (context, index) {
                  final field = _fields[index];
                  return _fieldCard(field, index);
                },
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isReadOnly ? null : _addField,
              icon: const Icon(Icons.add),
              label: const Text('新增欄位'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: _isReadOnly
          ? null
          : FloatingActionButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
            ),
      ),
    );
  }

  Future<void> _handleUnsavedChangesPop() async {
    final action = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (action) {
      case UnsavedChangesAction.discard:
        Navigator.of(context).pop();
      case UnsavedChangesAction.save:
        await _save();
      case UnsavedChangesAction.cancel:
      case null:
        break;
    }
  }

  String _encodeSnapshot() {
    return jsonEncode({
      'name': _nameController.text.trim(),
      'isLockable': _isLockable,
      'iconCodePoint': _selectedIconCodePoint,
      'fields': _fields.map((field) => field.toJson()).toList(),
    });
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _fieldCard(TemplateField field, int index) {
    return Card(
      key: ValueKey(field.id),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TemplateFieldType>(
                    value: field.type,
                    decoration: const InputDecoration(labelText: '欄位類型'),
                    items: TemplateFieldType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_fieldTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: _isReadOnly
                        ? null
                        : (value) {
                            if (value == null) return;
                            final nextDateMode = value == TemplateFieldType.date
                                ? field.dateMode
                                : DateFieldMode.dateOnly;
                            _updateField(
                              index,
                              field.copyWith(type: value, dateMode: nextDateMode),
                            );
                          },
                  ),
                ),
                if (!_isReadOnly) ...[
                  const SizedBox(width: 8),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle),
                  ),
                  IconButton(
                    tooltip: '刪除欄位',
                    onPressed: () => _removeField(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: field.label,
              readOnly: _isReadOnly,
              decoration: const InputDecoration(labelText: '欄位標題'),
              onChanged: (value) => _updateField(index, field.copyWith(label: value)),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: field.hint,
              readOnly: _isReadOnly,
              decoration: const InputDecoration(labelText: '提示字'),
              onChanged: (value) => _updateField(index, field.copyWith(hint: value)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('必填'),
              value: field.isRequired,
              onChanged: _isReadOnly
                  ? null
                  : (value) =>
                      _updateField(index, field.copyWith(isRequired: value)),
            ),
            if (field.type == TemplateFieldType.date) ...[
              const SizedBox(height: 8),
              Text(
                '日期模式',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              SegmentedButton<DateFieldMode>(
                segments: const [
                  ButtonSegment<DateFieldMode>(
                    value: DateFieldMode.dateOnly,
                    label: Text('僅日期'),
                  ),
                  ButtonSegment<DateFieldMode>(
                    value: DateFieldMode.dateTime,
                    label: Text('日期＋時分秒'),
                  ),
                ],
                selected: {field.dateMode},
                onSelectionChanged: _isReadOnly
                    ? null
                    : (selected) {
                        if (selected.isEmpty) return;
                        _updateField(
                          index,
                          field.copyWith(dateMode: selected.first),
                        );
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconPicker(BuildContext context) {
    final selectedIcon = templateIconFromCodePoint(_selectedIconCodePoint);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '模板 icon',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isReadOnly
              ? null
              : () => setState(() => _iconPickerExpanded = !_iconPickerExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.journalColors.cardBackground,
              border: Border.all(color: context.journalColors.inputBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  selectedIcon,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isReadOnly ? '內建模板 icon' : '點擊選擇 icon',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (!_isReadOnly)
                  Icon(
                    _iconPickerExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
              ],
            ),
          ),
        ),
        if (_iconPickerExpanded && !_isReadOnly) ...[
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: templateIconOptions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final icon = templateIconOptions[index];
              final isSelected = icon.codePoint == _selectedIconCodePoint;
              return InkWell(
                onTap: () => setState(() {
                  _selectedIconCodePoint = icon.codePoint;
                }),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : context.journalColors.inputBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Icon(icon),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  String _fieldTypeLabel(TemplateFieldType type) {
    switch (type) {
      case TemplateFieldType.largeText:
        return '大輸入框';
      case TemplateFieldType.text:
        return '短文字';
      case TemplateFieldType.image:
        return '圖片';
      case TemplateFieldType.rating:
        return '評分';
      case TemplateFieldType.date:
        return '日期';
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, item);
    });
  }

  void _addField() {
    setState(() {
      _fields.add(
        TemplateField(
          id: _uuid.v4(),
          type: TemplateFieldType.largeText,
          label: '',
          hint: '',
        ),
      );
    });
  }

  void _removeField(int index) {
    setState(() {
      _fields.removeAt(index);
    });
  }

  void _updateField(int index, TemplateField value) {
    setState(() {
      _fields[index] = value;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請至少新增一個欄位')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final now = DateTime.now();
    final existing = widget.template;
    final shouldSyncExisting = existing != null && !existing.isBuiltIn;
    final removedFieldIds = _getRemovedFieldIds(existing, _fields);
    final template = CollectionTemplate(
      id: existing?.id ?? _uuid.v4(),
      name: name,
      isBuiltIn: false,
      isLockable: _isLockable,
      iconCodePoint: _selectedIconCodePoint,
      fields: _fields,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      await _service.save(template);
      if (!mounted) return;
      var syncedCount = 0;
      if (shouldSyncExisting) {
        var removeDeletedFields = false;
        if (removedFieldIds.isNotEmpty) {
          final confirmedDelete = await _confirmDeleteRemovedFields(removedFieldIds.length);
          removeDeletedFields = confirmedDelete == true;
        }
        syncedCount = await _syncExistingCollections(
          template,
          removeDeletedFields: removeDeletedFields,
        );
      }
      if (!mounted) return;
      final message = syncedCount > 0
          ? '模板已儲存，已同步 $syncedCount 筆既有內容'
          : '模板已儲存';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('儲存失敗: $e')));
      setState(() => _isSaving = false);
    }
  }

  Set<String> _getRemovedFieldIds(
    CollectionTemplate? existing,
    List<TemplateField> nextFields,
  ) {
    if (existing == null) return const {};
    final oldIds = existing.fields.map((field) => field.id).toSet();
    final newIds = nextFields.map((field) => field.id).toSet();
    return oldIds.difference(newIds);
  }

  Future<bool?> _confirmDeleteRemovedFields(int removedCount) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('欄位刪除同步'),
        content: Text(
          '偵測到本次模板刪除了 $removedCount 個欄位。\n\n'
          '是否要一併刪除既有 collection 的這些欄位資料？\n'
          '若選擇保留，只會新增新欄位，不會刪除既有資料。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('保留既有欄位'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('刪除既有欄位'),
          ),
        ],
      ),
    );
  }

  Future<int> _syncExistingCollections(
    CollectionTemplate template, {
    required bool removeDeletedFields,
  }) async {
    final entries = await _customEntryManager.getByTemplateId(template.id);
    if (entries.isEmpty) return 0;

    final now = DateTime.now();
    final updatedEntries = <CustomEntry>[];
    for (final entry in entries) {
      final normalized = entry.normalizedByTemplate(
        template,
        removeDeletedFields: removeDeletedFields,
      );
      final oldJson = jsonEncode(entry.fieldValues);
      final newJson = jsonEncode(normalized.fieldValues);
      if (oldJson == newJson) continue;
      updatedEntries.add(normalized.copyWith(updateTime: now));
    }

    if (updatedEntries.isEmpty) return 0;
    await _customEntryManager.updateBatch(updatedEntries);
    return updatedEntries.length;
  }
}
