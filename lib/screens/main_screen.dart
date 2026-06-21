import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'records_screen.dart';
import 'record_list_screen.dart';
import '../models/diary_manager.dart';
import '../services/auth_service.dart';
import '../services/widget_launch_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  final AuthService _authService = AuthService();
  final DiaryManager _diaryManager = DiaryManager();
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeScreenKey),
      RecordsScreen(
        selectedDate: _selectedDate,
        onDateSelected: _onDateSelected,
      ),
    ];

    WidgetLaunchService.instance.registerDiaryChangedCallback(
      () => _homeScreenKey.currentState?.refresh(),
    );

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
      onDiaryChanged: () => _homeScreenKey.currentState?.refresh(),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToRecordList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecordListScreen()),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // 更新 RecordsScreen 的日期
        _screens[1] = RecordsScreen(
          selectedDate: _selectedDate,
          onDateSelected: _onDateSelected,
        );
      });
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      // 更新 RecordsScreen 的日期
      _screens[1] = RecordsScreen(
        selectedDate: _selectedDate,
        onDateSelected: _onDateSelected,
      );
    });
  }

  Future<void> _handleAuthAction() async {
    if (_authService.isSignedIn) {
      await _authService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已登出')),
        );
      }
    } else {
      final user = await _authService.signInWithGoogle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user == null ? '登入已取消' : '已登入：${user.displayName ?? user.email}',
            ),
          ),
        );
      }
      if (user != null) {
        await _diaryManager.syncAllPending();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _restoreFromCloud() async {
    if (!_authService.isSignedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入 Google 帳號')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('從 Google Drive 還原'),
        content: const Text(
          '將從 Google Drive 下載日記並合併到本機。'
          '若本機版本較新，則保留本機資料。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('還原'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _diaryManager.restoreFromCloud();
      if (mounted) {
        Navigator.pop(context);
        _homeScreenKey.currentState?.refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '還原完成：更新 ${result.restoredCount} 篇，'
              '略過 ${result.skippedCount} 篇',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('還原失敗: $e')),
        );
      }
    }
  }

  Future<void> _syncPendingNow() async {
    if (!_authService.isSignedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('請先登入 Google 帳號')),
        );
      }
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _diaryManager.syncAllPending();
      final pendingCount = await _diaryManager.getPendingSyncCount();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pendingCount == 0
                  ? '所有日記已同步至 Google Drive'
                  : '仍有 $pendingCount 篇待同步',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失敗: $e')),
        );
      }
    }
  }

  Future<void> _handleSettingsAction(String action) async {
    switch (action) {
      case 'restore':
        await _restoreFromCloud();
        break;
      case 'sync':
        await _syncPendingNow();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Journal' : 'Records'),
        backgroundColor: Theme.of(context).secondaryHeaderColor,
        actions: [
          if (_selectedIndex == 0)
            PopupMenuButton<String>(
              tooltip: '設定',
              onSelected: _handleSettingsAction,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'restore',
                  child: Text('從 Google Drive 還原'),
                ),
                PopupMenuItem(
                  value: 'sync',
                  child: Text('立即同步待上傳項目'),
                ),
              ],
              icon: const Icon(Icons.settings),
            ),
          StreamBuilder<User?>(
            stream: _authService.authStateChanges,
            builder: (context, snapshot) {
              final isSignedIn = snapshot.data != null;
              return IconButton(
                onPressed: _handleAuthAction,
                tooltip: isSignedIn ? '登出' : 'Google 登入',
                icon: isSignedIn
                    ? CircleAvatar(
                        radius: 14,
                        backgroundImage: snapshot.data?.photoURL != null
                            ? NetworkImage(snapshot.data!.photoURL!)
                            : null,
                        child: snapshot.data?.photoURL == null
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      )
                    : const Icon(Icons.login),
              );
            },
          ),
          if (_selectedIndex == 1)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: _selectDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.purple.shade600,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: _screens[_selectedIndex],
      floatingActionButton: _selectedIndex == 1 // 只在 Records tab 顯示
          ? FloatingActionButton(
              onPressed: _navigateToRecordList,
              child: const Icon(Icons.edit),
              tooltip: '查看記錄列表',
            )
          : null,
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
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}
