import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'collections_list_screen.dart';
import '../models/diary_manager.dart';
import '../services/auth_service.dart';
import '../services/diary_lock_service.dart';
import '../services/widget_launch_service.dart';
import '../widgets/pin_entry_dialog.dart';
import '../widgets/pin_setup_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final DiaryManager _diaryManager = DiaryManager();
  final DiaryLockService _lockService = DiaryLockService();
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final GlobalKey<CollectionsListScreenState> _collectionsListKey =
      GlobalKey<CollectionsListScreenState>();
  bool _hasPin = false;
  bool _encryptAllBackups = false;

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
    ];

    _loadSettings();
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

  Future<void> _loadSettings() async {
    final hasPin = await _lockService.hasPin();
    final encryptAllBackups = await _diaryManager.getEncryptAllBackups();
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _encryptAllBackups = encryptAllBackups;
      });
    }
  }

  Future<void> _loadHasPin() async {
    await _loadSettings();
  }

  Future<void> _toggleEncryptAllBackups() async {
    final enabling = !_encryptAllBackups;

    if (enabling) {
      if (!await _lockService.hasPin()) {
        final setupPin = await showPinSetupDialog(
          context,
          title: '設定 PIN',
          subtitle: '全部備份加密需要 PIN',
        );
        if (setupPin == null || !mounted) return;
        await _lockService.setPin(setupPin);
      } else if (!await _ensureSessionPin(subtitle: '啟用全部備份加密需要 PIN')) {
        return;
      }
    }

    await _diaryManager.setEncryptAllBackups(enabling);
    if (!mounted) return;

    setState(() {
      _encryptAllBackups = enabling;
      _hasPin = true;
    });

    if (enabling && _authService.isSignedIn) {
      if (!await _ensureSessionPin(subtitle: '同步加密備份需要 PIN')) return;
      await _syncPendingNow();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabling
                ? '已啟用全部備份加密，日記將以 PIN 加密上傳至 Google Drive'
                : '已關閉全部備份加密，下次同步將上傳明文格式',
          ),
        ),
      );
    }
  }

  Future<bool> _ensureSessionPin({String? subtitle}) async {
    if (_lockService.hasSessionPin) return true;
    if (!await _lockService.hasPin()) return true;
    if (!mounted) return false;

    final pin = await showPinEntryDialog(
      context,
      title: '輸入 PIN',
      subtitle: subtitle ?? '處理上鎖日記需要 PIN',
    );
    if (pin == null) return false;

    if (!await _lockService.verifyPin(pin)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN 錯誤')),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _changePin() async {
    final oldPin = await showPinEntryDialog(
      context,
      title: '輸入目前 PIN',
    );
    if (oldPin == null || !mounted) return;

    if (!await _lockService.verifyPin(oldPin)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目前 PIN 錯誤，無法變更')),
        );
      }
      return;
    }

    final newPin = await showPinSetupDialog(
      context,
      title: '設定新 PIN',
    );
    if (newPin == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _diaryManager.reencryptAllLockedDiaries(oldPin, newPin);
      final changed = await _lockService.changePin(oldPin, newPin);
      if (mounted) {
        Navigator.pop(context);
        if (changed) {
          await _diaryManager.syncAllPending();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN 已更新，上鎖日記已重新加密')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN 更新失敗')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PIN 更新失敗: $e')),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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

    if (await _diaryManager.shouldPromptPinBeforeRestore()) {
      if (!await _ensureSessionPin(subtitle: '還原上鎖日記需要 PIN')) return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await _diaryManager.restoreFromCloud();
      if (mounted) {
        Navigator.pop(context);
        _refreshCollections();
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

    if (await _diaryManager.needsPinForSync()) {
      if (!await _ensureSessionPin(subtitle: '同步上鎖日記需要 PIN')) return;
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
      case 'change_pin':
        await _changePin();
        break;
      case 'toggle_encrypt_all':
        await _toggleEncryptAllBackups();
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
              onOpened: _loadHasPin,
              onSelected: _handleSettingsAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'restore',
                  child: Text('從 Google Drive 還原'),
                ),
                const PopupMenuItem(
                  value: 'sync',
                  child: Text('立即同步待上傳項目'),
                ),
                PopupMenuItem(
                  value: 'toggle_encrypt_all',
                  child: Text(
                    _encryptAllBackups
                        ? '全部備份加密：開'
                        : '全部備份加密：關',
                  ),
                ),
                if (_hasPin)
                  const PopupMenuItem(
                    value: 'change_pin',
                    child: Text('變更 PIN'),
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
        ],
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
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}
