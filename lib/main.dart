import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/main_screen.dart';
import 'services/widget_launch_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> _handleIncomingUri(Uri? uri) async {
  final action = WidgetLaunchService.instance.parseUri(uri);
  if (action == null) return;

  WidgetLaunchService.instance.handleUri(uri);

  final context = rootNavigatorKey.currentContext;
  if (context == null) return;

  final pendingAction = WidgetLaunchService.instance.consumePendingAction();
  if (pendingAction == null) return;

  await WidgetLaunchService.instance.navigateToQuickAdd(
    context,
    pendingAction,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final appLinks = AppLinks();
  final initialUri = await appLinks.getInitialLink();
  WidgetLaunchService.instance.handleUri(initialUri);

  appLinks.uriLinkStream.listen(_handleIncomingUri);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: '日記本',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
