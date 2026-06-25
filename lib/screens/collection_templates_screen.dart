import 'package:flutter/material.dart';

import '../models/collection_template.dart';
import '../services/collection_template_service.dart';
import 'template_editor_screen.dart';

class CollectionTemplatesScreen extends StatefulWidget {
  const CollectionTemplatesScreen({super.key, CollectionTemplateService? service})
      : _service = service;

  final CollectionTemplateService? _service;

  @override
  State<CollectionTemplatesScreen> createState() =>
      _CollectionTemplatesScreenState();
}

class _CollectionTemplatesScreenState extends State<CollectionTemplatesScreen> {
  late final CollectionTemplateService _service;
  late Future<List<CollectionTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? CollectionTemplateService();
    _reload();
  }

  void _reload() {
    _templatesFuture = _service.getAll();
  }

  Future<void> _openEditor({CollectionTemplate? template}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateEditorScreen(
          template: template,
          service: _service,
        ),
      ),
    );
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _deleteTemplate(CollectionTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除模板'),
        content: Text('確定刪除「${template.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _service.delete(template.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已刪除「${template.name}」')),
    );
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection 模板'),
        actions: [
          IconButton(
            tooltip: '新增模板',
            onPressed: _openEditor,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: FutureBuilder<List<CollectionTemplate>>(
        future: _templatesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('載入失敗: ${snapshot.error}'));
          }
          final templates = snapshot.data ?? <CollectionTemplate>[];
          final builtIn = templates.where((item) => item.isBuiltIn).toList();
          final custom = templates.where((item) => !item.isBuiltIn).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: _openEditor,
                icon: const Icon(Icons.add),
                label: const Text('新增模板'),
              ),
              const SizedBox(height: 16),
              _sectionTitle('內建模板'),
              ...builtIn.map((item) => _templateTile(item)),
              const SizedBox(height: 12),
              _sectionTitle('自訂模板'),
              if (custom.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('尚無自訂模板，點上方按鈕建立'),
                ),
              ...custom.map((item) => _templateTile(item, canDelete: true)),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _templateTile(CollectionTemplate template, {bool canDelete = false}) {
    final tile = Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(template.isBuiltIn ? Icons.lock_outline : Icons.tune),
        title: Text(template.name),
        subtitle: Text(_subtitle(template)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openEditor(template: template),
      ),
    );

    if (!canDelete) return tile;
    return Dismissible(
      key: ValueKey(template.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteTemplate(template);
        return false;
      },
      child: tile,
    );
  }

  String _subtitle(CollectionTemplate template) {
    final lockLabel = template.isLockable ? '可上鎖' : '不可上鎖';
    final fieldCount = '${template.fields.length} 個欄位';
    final preview = template.fields
        .take(3)
        .map((field) => field.label.trim().isEmpty ? '未命名欄位' : field.label)
        .join(' / ');
    if (preview.isEmpty) {
      return '$lockLabel · $fieldCount';
    }
    return '$lockLabel · $fieldCount · $preview';
  }
}
