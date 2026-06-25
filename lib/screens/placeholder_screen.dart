import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        backgroundColor: context.journalColors.cardBackground,
      ),
      body: const Center(
        child: Text(
          '功能開發中',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
