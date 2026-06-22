import 'package:flutter_test/flutter_test.dart';
import 'package:journal/services/widget_launch_service.dart';

void main() {
  final service = WidgetLaunchService.instance;

  group('WidgetLaunchService.parseUri', () {
    test('parses diary deep link', () {
      expect(
        service.parseUri(Uri.parse(WidgetLaunchService.diaryUri)),
        QuickAddAction.diary,
      );
    });

    test('parses recipe deep link', () {
      expect(
        service.parseUri(Uri.parse(WidgetLaunchService.recipeUri)),
        QuickAddAction.recipe,
      );
    });

    test('parses todo deep link', () {
      expect(
        service.parseUri(Uri.parse(WidgetLaunchService.todoUri)),
        QuickAddAction.todo,
      );
    });

    test('parses review deep link', () {
      expect(
        service.parseUri(Uri.parse(WidgetLaunchService.reviewUri)),
        QuickAddAction.review,
      );
    });

    test('returns null for unrelated URI', () {
      expect(service.parseUri(Uri.parse('https://example.com')), isNull);
    });
  });

  group('WidgetLaunchService pending action', () {
    test('handleUri stores and consumePendingAction clears action', () {
      service.handleUri(Uri.parse(WidgetLaunchService.todoUri));
      expect(service.consumePendingAction(), QuickAddAction.todo);
      expect(service.consumePendingAction(), isNull);
    });
  });
}
