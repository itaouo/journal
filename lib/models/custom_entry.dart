import 'dart:convert';

import 'collection_template.dart';
import 'collection.dart';

class CustomEntry extends Collection {
  final String templateId;
  final bool isLocked;
  final Map<String, dynamic> fieldValues;

  CustomEntry({
    required super.id,
    required super.createTime,
    required super.updateTime,
    super.isDeleted = false,
    required this.templateId,
    this.isLocked = false,
    Map<String, dynamic>? fieldValues,
  }) : fieldValues = fieldValues ?? const {};

  CustomEntry copyWith({
    String? templateId,
    bool? isLocked,
    Map<String, dynamic>? fieldValues,
    DateTime? updateTime,
    bool? isDeleted,
  }) {
    return CustomEntry(
      id: id,
      createTime: createTime,
      updateTime: updateTime ?? this.updateTime,
      isDeleted: isDeleted ?? this.isDeleted,
      templateId: templateId ?? this.templateId,
      isLocked: isLocked ?? this.isLocked,
      fieldValues: fieldValues ?? this.fieldValues,
    );
  }

  String get fieldValuesJson => jsonEncode(fieldValues);

  CustomEntry normalizedByTemplate(
    CollectionTemplate template, {
    bool removeDeletedFields = true,
  }) {
    final normalized = <String, dynamic>{};

    if (!removeDeletedFields) {
      normalized.addAll(fieldValues);
    }

    for (final field in template.fields) {
      final oldValue = fieldValues[field.id];
      final isCompatible = _isCompatibleValue(field, oldValue);
      normalized[field.id] = isCompatible ? oldValue : _emptyValueFor(field);

      if (field.type == TemplateFieldType.rating) {
        final oldNote = fieldValues['${field.id}__note'];
        if (oldNote is String && oldNote.trim().isNotEmpty) {
          normalized['${field.id}__note'] = oldNote;
        }
      }
    }

    return copyWith(fieldValues: normalized);
  }

  bool _isCompatibleValue(TemplateField field, dynamic value) {
    if (value == null) return true;
    switch (field.type) {
      case TemplateFieldType.text:
      case TemplateFieldType.largeText:
        return value is String;
      case TemplateFieldType.date:
        if (value is! String) return false;
        return DateTime.tryParse(value) != null;
      case TemplateFieldType.image:
        if (value is! List) return false;
        return value.every((item) => item is String);
      case TemplateFieldType.rating:
        return value is int;
    }
  }

  dynamic _emptyValueFor(TemplateField field) {
    switch (field.type) {
      case TemplateFieldType.text:
      case TemplateFieldType.largeText:
      case TemplateFieldType.date:
        return '';
      case TemplateFieldType.image:
        return <String>[];
      case TemplateFieldType.rating:
        return null;
    }
  }
}
