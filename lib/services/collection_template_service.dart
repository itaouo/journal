import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/collection_template.dart';

abstract class CollectionTemplateStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureCollectionTemplateStorage
    implements CollectionTemplateStorage {
  FlutterSecureCollectionTemplateStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryCollectionTemplateStorage implements CollectionTemplateStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

class CollectionTemplateService {
  CollectionTemplateService({CollectionTemplateStorage? storage})
      : _storage = storage ?? FlutterSecureCollectionTemplateStorage();

  static const _templatesKey = 'collection_templates_v1';
  static const builtInDiaryId = 'built_in_diary';
  static const builtInReviewId = 'built_in_review';

  final CollectionTemplateStorage _storage;

  List<CollectionTemplate> get _builtInTemplates {
    final now = DateTime.now();
    return [
      CollectionTemplate(
        id: builtInDiaryId,
        name: '日記',
        isBuiltIn: true,
        isLockable: true,
        iconCodePoint: Icons.book_outlined.codePoint,
        createdAt: now,
        updatedAt: now,
        fields: const [
          TemplateField(
            id: 'diary_date',
            type: TemplateFieldType.date,
            label: '日期',
            hint: '選擇日期',
            isRequired: true,
            dateMode: DateFieldMode.dateOnly,
          ),
          TemplateField(
            id: 'diary_content',
            type: TemplateFieldType.largeText,
            label: '內容',
            hint: '寫下今天的心情和發生的事...',
            isRequired: true,
          ),
          TemplateField(
            id: 'diary_images',
            type: TemplateFieldType.image,
            label: '圖片',
            hint: '可加入多張圖片',
          ),
        ],
      ),
      CollectionTemplate(
        id: builtInReviewId,
        name: 'Review',
        isBuiltIn: true,
        isLockable: false,
        iconCodePoint: Icons.rate_review_outlined.codePoint,
        createdAt: now,
        updatedAt: now,
        fields: const [
          TemplateField(
            id: 'review_title',
            type: TemplateFieldType.text,
            label: '標題',
            hint: '作品名稱',
            isRequired: true,
          ),
          TemplateField(
            id: 'review_experience_date',
            type: TemplateFieldType.date,
            label: '觀看 / 閱讀日期',
            hint: '選擇日期',
            isRequired: true,
            dateMode: DateFieldMode.dateOnly,
          ),
          TemplateField(
            id: 'review_summary',
            type: TemplateFieldType.largeText,
            label: '劇情概要',
            hint: '簡述劇情或內容...',
          ),
          TemplateField(
            id: 'review_key_quotes',
            type: TemplateFieldType.largeText,
            label: '核心金句',
            hint: '印象深刻的台詞或段落...',
          ),
          TemplateField(
            id: 'review_thoughts',
            type: TemplateFieldType.largeText,
            label: '心得',
            hint: '寫下你的觀後或讀後感想...',
          ),
          TemplateField(
            id: 'review_rating',
            type: TemplateFieldType.rating,
            label: '推薦指數',
            hint: '可填寫分數與補充說明',
          ),
          TemplateField(
            id: 'review_images',
            type: TemplateFieldType.image,
            label: '圖片',
            hint: '可加入多張圖片',
          ),
        ],
      ),
    ];
  }

  Future<List<CollectionTemplate>> getAll() async {
    final custom = await _readCustomTemplates();
    return [..._builtInTemplates, ...custom];
  }

  Future<void> save(CollectionTemplate template) async {
    if (template.isBuiltIn) {
      throw ArgumentError('內建模板不可覆寫');
    }
    final custom = await _readCustomTemplates();
    final index = custom.indexWhere((item) => item.id == template.id);
    if (index >= 0) {
      custom[index] = template;
    } else {
      custom.add(template);
    }
    await _writeCustomTemplates(custom);
  }

  Future<void> delete(String id) async {
    if (id == builtInDiaryId || id == builtInReviewId) return;
    final custom = await _readCustomTemplates();
    custom.removeWhere((item) => item.id == id);
    await _writeCustomTemplates(custom);
  }

  Future<List<CollectionTemplate>> _readCustomTemplates() async {
    final raw = await _storage.read(_templatesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => CollectionTemplate.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((item) => !item.isBuiltIn)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCustomTemplates(List<CollectionTemplate> templates) async {
    if (templates.isEmpty) {
      await _storage.delete(_templatesKey);
      return;
    }
    final payload = templates.map((item) => item.toJson()).toList();
    await _storage.write(_templatesKey, jsonEncode(payload));
  }
}
