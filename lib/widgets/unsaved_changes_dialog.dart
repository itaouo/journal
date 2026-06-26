import 'package:flutter/material.dart';

enum UnsavedChangesAction { cancel, discard, save }

Future<UnsavedChangesAction?> showUnsavedChangesDialog(BuildContext context) {
  return showDialog<UnsavedChangesAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('未儲存的變更'),
      content: const Text('您有未儲存的變更，確定要離開嗎？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(UnsavedChangesAction.cancel),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(UnsavedChangesAction.discard),
          child: const Text('放棄'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(UnsavedChangesAction.save),
          child: const Text('儲存'),
        ),
      ],
    ),
  );
}
