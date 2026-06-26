import 'package:flutter/material.dart';

/// Icons selectable for collection templates. Must stay const for release
/// builds so Material icon fonts can be tree-shaken.
const templateIconOptions = <IconData>[
  Icons.note_outlined,
  Icons.book_outlined,
  Icons.rate_review_outlined,
  Icons.movie_outlined,
  Icons.menu_book_outlined,
  Icons.library_music_outlined,
  Icons.restaurant_menu_outlined,
  Icons.fitness_center_outlined,
  Icons.travel_explore_outlined,
  Icons.home_outlined,
  Icons.work_outline,
  Icons.school_outlined,
  Icons.pets_outlined,
  Icons.favorite_border,
  Icons.celebration_outlined,
  Icons.camera_alt_outlined,
  Icons.palette_outlined,
  Icons.lightbulb_outline,
  Icons.check_box_outlined,
  Icons.list_alt_outlined,
  Icons.event_note_outlined,
  Icons.self_improvement_outlined,
  Icons.sports_esports_outlined,
  Icons.star_outline,
];

IconData templateIconFromCodePoint(int codePoint) {
  for (final icon in templateIconOptions) {
    if (icon.codePoint == codePoint) return icon;
  }
  return templateIconOptions.first;
}
