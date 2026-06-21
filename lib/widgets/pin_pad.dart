import 'package:flutter/material.dart';

import '../services/diary_lock_service.dart';

class PinPadController {
  PinPadController({this.onCompleted});

  void Function(String pin)? onCompleted;

  String _value = '';

  String get value => _value;

  int get length => _value.length;

  void addDigit(int digit) {
    if (_value.length >= DiaryLockService.pinLength) return;
    _value += digit.toString();
    if (_value.length == DiaryLockService.pinLength) {
      onCompleted?.call(_value);
    }
  }

  void removeLast() {
    if (_value.isEmpty) return;
    _value = _value.substring(0, _value.length - 1);
  }

  void clear() {
    _value = '';
  }
}

class PinDots extends StatelessWidget {
  final int filledCount;
  final int totalCount;

  const PinDots({
    super.key,
    required this.filledCount,
    this.totalCount = DiaryLockService.pinLength,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (index) {
        final filled = index < filledCount;
        return Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: filled ? colorScheme.primary : Colors.grey,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}

class PinNumpad extends StatelessWidget {
  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;

  const PinNumpad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(context, [1, 2, 3]),
        const SizedBox(height: 8),
        _buildRow(context, [4, 5, 6]),
        const SizedBox(height: 8),
        _buildRow(context, [7, 8, 9]),
        const SizedBox(height: 8),
        _buildRow(context, [null, 0, -1]),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<int?> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) => _buildKey(context, key)).toList(),
    );
  }

  Widget _buildKey(BuildContext context, int? key) {
    if (key == null) {
      return const SizedBox(width: 72, height: 56);
    }

    if (key == -1) {
      return SizedBox(
        width: 72,
        height: 56,
        child: IconButton(
          onPressed: onBackspace,
          icon: const Icon(Icons.backspace_outlined),
        ),
      );
    }

    return SizedBox(
      width: 72,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => onDigit(key),
          child: Center(
            child: Text(
              '$key',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PinPadInput extends StatefulWidget {
  final PinPadController controller;
  final String? errorText;

  const PinPadInput({
    super.key,
    required this.controller,
    this.errorText,
  });

  @override
  State<PinPadInput> createState() => _PinPadInputState();
}

class _PinPadInputState extends State<PinPadInput> {
  void _addDigit(int digit) {
    setState(() {
      widget.controller.addDigit(digit);
    });
  }

  void _removeLast() {
    setState(() {
      widget.controller.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PinDots(filledCount: widget.controller.length),
        if (widget.errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.errorText!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        PinNumpad(
          onDigit: _addDigit,
          onBackspace: _removeLast,
        ),
      ],
    );
  }
}
