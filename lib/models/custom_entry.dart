import 'dart:convert';

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
}
