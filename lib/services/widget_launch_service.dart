import 'package:flutter/material.dart';
import '../screens/add_diary_screen.dart';
import '../screens/placeholder_screen.dart';

enum QuickAddAction { diary, recipe, todo }

class WidgetLaunchService {
  WidgetLaunchService._();

  static final WidgetLaunchService instance = WidgetLaunchService._();

  static const diaryUri = 'journal://add/diary';
  static const recipeUri = 'journal://add/recipe';
  static const todoUri = 'journal://add/todo';

  VoidCallback? _onDiaryChanged;

  void registerDiaryChangedCallback(VoidCallback? callback) {
    _onDiaryChanged = callback;
  }

  QuickAddAction? parseUri(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != 'journal' || uri.host != 'add') return null;

    switch (uri.pathSegments.firstOrNull) {
      case 'diary':
        return QuickAddAction.diary;
      case 'recipe':
        return QuickAddAction.recipe;
      case 'todo':
        return QuickAddAction.todo;
      default:
        return null;
    }
  }

  void handleUri(Uri? uri) {
    final action = parseUri(uri);
    if (action != null) {
      _pendingAction = action;
    }
  }

  QuickAddAction? _pendingAction;

  QuickAddAction? consumePendingAction() {
    final action = _pendingAction;
    _pendingAction = null;
    return action;
  }

  Future<void> navigateToQuickAdd(
    BuildContext context,
    QuickAddAction action, {
    VoidCallback? onDiaryChanged,
  }) async {
    switch (action) {
      case QuickAddAction.diary:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddDiaryScreen()),
        );
        onDiaryChanged?.call();
        _onDiaryChanged?.call();
      case QuickAddAction.recipe:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaceholderScreen(title: '食譜'),
          ),
        );
      case QuickAddAction.todo:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const PlaceholderScreen(title: 'Todo'),
          ),
        );
    }
  }
}
