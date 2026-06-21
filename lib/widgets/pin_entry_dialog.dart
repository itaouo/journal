import 'package:flutter/material.dart';

import '../services/diary_lock_service.dart';
import 'pin_pad.dart';

Future<String?> showPinEntryDialog(
  BuildContext context, {
  String title = '輸入 PIN',
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PinEntryDialog(
      title: title,
      subtitle: subtitle,
    ),
  );
}

class PinEntryDialog extends StatefulWidget {
  final String title;
  final String? subtitle;

  const PinEntryDialog({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  late final PinPadController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = PinPadController(onCompleted: _submit);
  }

  void _submit(String pin) {
    if (!DiaryLockService.isValidPinFormat(pin)) {
      setState(() {
        _errorText = 'PIN 必須為 ${DiaryLockService.pinLength} 位數字';
        _controller.clear();
      });
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          PinPadInput(
            controller: _controller,
            errorText: _errorText,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
