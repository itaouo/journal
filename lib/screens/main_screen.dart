import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'collections_list_screen.dart';
import 'settings_screen.dart';
import '../services/widget_launch_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final GlobalKey<CollectionsListScreenState> _collectionsListKey =
      GlobalKey<CollectionsListScreenState>();
  final GlobalKey<SettingsScreenState> _settingsScreenKey =
      GlobalKey<SettingsScreenState>();

  late final List<Widget> _screens;

  void _refreshCollections() {
    _homeScreenKey.currentState?.refresh();
    _collectionsListKey.currentState?.refresh();
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeScreenKey),
      CollectionsListScreen(key: _collectionsListKey),
      SettingsScreen(
        key: _settingsScreenKey,
        onCollectionsChanged: _refreshCollections,
      ),
    ];

    WidgetLaunchService.instance.registerDiaryChangedCallback(_refreshCollections);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingWidgetLaunch();
    });
  }

  Future<void> _handlePendingWidgetLaunch() async {
    final action = WidgetLaunchService.instance.consumePendingAction();
    if (action == null || !mounted) return;

    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted) return;

    await WidgetLaunchService.instance.navigateToQuickAdd(
      context,
      action,
      onDiaryChanged: _refreshCollections,
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 2) {
      _settingsScreenKey.currentState?.refreshSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
        backgroundColor: Theme.of(context).secondaryHeaderColor,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.collections),
            label: 'Collections',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}
