import 'package:flutter/material.dart';

import '../services/diary_lock_service.dart';
import 'pin_pad.dart';

Future<String?> showPinSetupDialog(
  BuildContext context, {
  String title = '設定 PIN',
  String? subtitle,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PinSetupDialog(
      title: title,
      subtitle: subtitle,
    ),
  );
}

class PinSetupDialog extends StatefulWidget {
  final String title;
  final String? subtitle;

  const PinSetupDialog({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  late final PinPadController _controller;
  String? _firstPin;
  String? _errorText;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _controller = PinPadController(onCompleted: _onPinCompleted);
  }

  String get _phaseLabel =>
      _isConfirming ? '再次輸入 PIN 確認' : '輸入新 PIN';

  void _onPinCompleted(String pin) {
    if (!DiaryLockService.isValidPinFormat(pin)) {
      setState(() {
        _errorText = 'PIN 必須為 ${DiaryLockService.pinLength} 位數字';
        _controller.clear();
      });
      return;
    }

    if (!_isConfirming) {
      setState(() {
        _firstPin = pin;
        _isConfirming = true;
        _errorText = null;
        _controller.clear();
      });
      return;
    }

    if (pin != _firstPin) {
      setState(() {
        _errorText = '兩次輸入的 PIN 不一致';
        _firstPin = null;
        _isConfirming = false;
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
            const SizedBox(height: 8),
          ],
          const Text(
            '若忘記 PIN，上鎖日記與加密備份將無法還原。',
            style: TextStyle(color: Colors.orange, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _phaseLabel,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
