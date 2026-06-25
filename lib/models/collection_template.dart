import 'package:flutter/material.dart';

enum TemplateFieldType { largeText, text, image, rating, date }

enum DateFieldMode { dateOnly, dateTime }

TemplateFieldType templateFieldTypeFromString(String? value) {
  if (value == null) return TemplateFieldType.text;
  for (final type in TemplateFieldType.values) {
    if (type.name == value) return type;
  }
  return TemplateFieldType.text;
}

DateFieldMode dateFieldModeFromString(String? value) {
  if (value == null) return DateFieldMode.dateOnly;
  for (final mode in DateFieldMode.values) {
    if (mode.name == value) return mode;
  }
  return DateFieldMode.dateOnly;
}

class TemplateField {
  final String id;
  final TemplateFieldType type;
  final String label;
  final String hint;
  final bool isRequired;
  final DateFieldMode dateMode;

  const TemplateField({
    required this.id,
    required this.type,
    required this.label,
    required this.hint,
    this.isRequired = false,
    this.dateMode = DateFieldMode.dateOnly,
  });

  TemplateField copyWith({
    String? id,
    TemplateFieldType? type,
    String? label,
    String? hint,
    bool? isRequired,
    DateFieldMode? dateMode,
  }) {
    return TemplateField(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      hint: hint ?? this.hint,
      isRequired: isRequired ?? this.isRequired,
      dateMode: dateMode ?? this.dateMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'label': label,
      'hint': hint,
      'isRequired': isRequired,
      'dateMode': dateMode.name,
    };
  }

  factory TemplateField.fromJson(Map<String, dynamic> json) {
    return TemplateField(
      id: (json['id'] as String?) ?? '',
      type: templateFieldTypeFromString(json['type'] as String?),
      label: (json['label'] as String?) ?? '',
      hint: (json['hint'] as String?) ?? '',
      isRequired: (json['isRequired'] as bool?) ?? false,
      dateMode: dateFieldModeFromString(json['dateMode'] as String?),
    );
  }
}

class CollectionTemplate {
  static const defaultIconCodePoint = 62000;

  final String id;
  final String name;
  final bool isBuiltIn;
  final bool isLockable;
  final int iconCodePoint;
  final List<TemplateField> fields;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CollectionTemplate({
    required this.id,
    required this.name,
    required this.isBuiltIn,
    required this.isLockable,
    this.iconCodePoint = defaultIconCodePoint,
    required this.fields,
    required this.createdAt,
    required this.updatedAt,
  });

  CollectionTemplate copyWith({
    String? id,
    String? name,
    bool? isBuiltIn,
    bool? isLockable,
    int? iconCodePoint,
    List<TemplateField>? fields,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollectionTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isLockable: isLockable ?? this.isLockable,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      fields: fields ?? this.fields,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isBuiltIn': isBuiltIn,
      'isLockable': isLockable,
      'iconCodePoint': iconCodePoint,
      'fields': fields.map((field) => field.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CollectionTemplate.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    final fields = rawFields is List
        ? rawFields
              .whereType<Map>()
              .map(
                (field) => TemplateField.fromJson(
                  field.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList()
        : <TemplateField>[];

    return CollectionTemplate(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      isBuiltIn: (json['isBuiltIn'] as bool?) ?? false,
      isLockable: (json['isLockable'] as bool?) ?? false,
      iconCodePoint:
          (json['iconCodePoint'] as int?) ?? defaultIconCodePoint,
      fields: fields,
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
}
