import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RatingInput extends StatefulWidget {
  final int? rating;
  final String? ratingNote;
  final ValueChanged<int?> onRatingChanged;
  final ValueChanged<String> onRatingNoteChanged;

  const RatingInput({
    super.key,
    required this.rating,
    required this.ratingNote,
    required this.onRatingChanged,
    required this.onRatingNoteChanged,
  });

  @override
  State<RatingInput> createState() => _RatingInputState();
}

class _RatingInputState extends State<RatingInput> {
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.ratingNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onStarTap(int star) {
    if (widget.rating == star) {
      widget.onRatingChanged(null);
    } else {
      widget.onRatingChanged(star);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (index) {
            final star = index + 1;
            final filled = widget.rating != null && star <= widget.rating!;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () => _onStarTap(star),
              icon: Icon(
                filled ? Icons.star : Icons.star_border,
                color: filled ? Colors.amber : Colors.grey,
                size: 32,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          onChanged: widget.onRatingNoteChanged,
          decoration: InputDecoration(
            hintText: '備註（選填，如：必看、普普）',
            filled: true,
            fillColor: context.journalColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.journalColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.journalColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}
