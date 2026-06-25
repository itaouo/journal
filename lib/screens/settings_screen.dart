import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/diary_manager.dart';
import '../services/auth_service.dart';
import '../services/backup_settings_service.dart';
import '../services/diary_lock_service.dart';
import '../widgets/pin_entry_dialog.dart';
import '../widgets/pin_setup_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onCollectionsChanged;

  const SettingsScreen({super.key, this.onCollectionsChanged});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final DiaryManager _diaryManager = DiaryManager();
  final DiaryLockService _lockService = DiaryLockService();
  final BackupSettingsService _backupSettings = BackupSettingsService();
  bool _hasPin = false;
  bool _encryptAllBackups = false;
  LockPinPromptMode _lockPinPromptMode = LockPinPromptMode.perLockedDiary;
  DateTime? _lastSyncAt;
  DateTime? _lastRestoreAt;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> refreshSettings() => _loadSettings();

  Future<void> _loadSettings() async {
    final hasPin = await _lockService.hasPin();
    final encryptAllBackups = await _diaryManager.getEncryptAllBackups();
    final lastSyncAt = await _diaryManager.getLastSyncAt();
    final lastRestoreAt = await _diaryManager.getLastRestoreAt();
    final lockPinPromptMode = await _backupSettings.getLockPinPromptMode();
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _encryptAllBackups = encryptAllBackups;
        _lastSyncAt = lastSyncAt;
        _lastRestoreAt = lastRestoreAt;
        _lockPinPromptMode = lockPinPromptMode;
      });
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final local = dateTime.toLocal();
    final year = local.year.toString();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year/$month/$day $hour:$minute';
  }

  Future<void> _toggleEncryptAllBackups(bool value) async {
    final enabling = value;

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

  void _showEncryptAllBackupsHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全部備份加密'),
        content: const Text(
          '此選項決定上傳至 Google Drive 的日記是否全部加密。\n\n'
          '關閉時：只有「上鎖」的日記會以 PIN 加密備份，其餘日記以明文格式上傳。\n\n'
          '開啟時：所有日記（含未上鎖）都會以 PIN 加密後上傳。\n\n'
          '啟用需要設定 PIN；同步或還原加密備份時也需輸入 PIN。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLockPinPromptModeDialog() async {
    if (!await _lockService.hasPin()) return;
    if (!mounted) return;

    final pin = await showPinEntryDialog(
      context,
      title: '輸入 PIN',
      subtitle: '變更上鎖日記 PIN 設定需要 PIN',
    );
    if (pin == null) return;

    if (!await _lockService.verifyPin(pin)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN 錯誤')),
        );
      }
      return;
    }

    var selectedMode = _lockPinPromptMode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('上鎖日記 PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<LockPinPromptMode>(
                title: const Text('每次開啟都輸入 PIN'),
                value: LockPinPromptMode.perLockedDiary,
                groupValue: selectedMode,
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selectedMode = value);
                },
              ),
              RadioListTile<LockPinPromptMode>(
                title: const Text('本次 App 解鎖一次即可'),
                value: LockPinPromptMode.oncePerAppSession,
                groupValue: selectedMode,
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => selectedMode = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確定'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted || selectedMode == _lockPinPromptMode) {
      return;
    }

    await _backupSettings.setLockPinPromptMode(selectedMode);
    if (selectedMode == LockPinPromptMode.perLockedDiary) {
      _lockService.resetSession();
    }
    if (mounted) {
      setState(() {
        _lockPinPromptMode = selectedMode;
      });
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
        widget.onCollectionsChanged?.call();
        await _loadSettings();
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
      await _diaryManager.recordLastSyncAt();
      final pendingCount = await _diaryManager.getPendingSyncCount();
      if (mounted) {
        Navigator.pop(context);
        await _loadSettings();
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

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.purple.shade800,
        ),
      ),
    );
  }

  Widget _cloudBackupActionTile({
    required IconData icon,
    required String title,
    required DateTime? lastActionAt,
    required String emptyLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      lastActionAt == null
                          ? emptyLabel
                          : _formatDateTime(lastActionAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _sectionHeader('帳號'),
        StreamBuilder<User?>(
          stream: _authService.authStateChanges,
          builder: (context, snapshot) {
            final user = snapshot.data;
            final isSignedIn = user != null;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (isSignedIn) ...[
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: user.photoURL != null
                            ? NetworkImage(user.photoURL!)
                            : null,
                        child: user.photoURL == null
                            ? const Icon(Icons.person, size: 28)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.displayName ?? user.email ?? '已登入',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user.email != null && user.displayName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.email!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _handleAuthAction,
                        icon: const Icon(Icons.logout),
                        label: const Text('登出'),
                      ),
                    ] else ...[
                      const Icon(Icons.account_circle_outlined, size: 48),
                      const SizedBox(height: 12),
                      const Text('尚未登入 Google 帳號'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _handleAuthAction,
                        icon: const Icon(Icons.login),
                        label: const Text('Google 登入'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        _sectionHeader('雲端備份'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.purple.shade50,
          child: Column(
            children: [
              _cloudBackupActionTile(
                icon: Icons.cloud_download_outlined,
                title: '從 Google Drive 還原',
                lastActionAt: _lastRestoreAt,
                emptyLabel: '尚未還原',
                onTap: _restoreFromCloud,
              ),
              const Divider(height: 1),
              _cloudBackupActionTile(
                icon: Icons.cloud_upload_outlined,
                title: '立即同步待上傳項目',
                lastActionAt: _lastSyncAt,
                emptyLabel: '尚未同步',
                onTap: _syncPendingNow,
              ),
            ],
          ),
        ),
        _sectionHeader('安全'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.purple.shade50,
          child: Column(
            children: [
              GestureDetector(
                onLongPress: _showEncryptAllBackupsHelp,
                child: SwitchListTile(
                  secondary: const Icon(Icons.enhanced_encryption_outlined),
                  title: const Text('全部備份加密'),
                  value: _encryptAllBackups,
                  onChanged: _toggleEncryptAllBackups,
                ),
              ),
              if (_hasPin) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_clock_outlined),
                  title: const Text('上鎖日記 PIN'),
                  subtitle: Text(lockPinPromptModeLabel(_lockPinPromptMode)),
                  onTap: _showLockPinPromptModeDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pin_outlined),
                  title: const Text('變更 PIN'),
                  onTap: _changePin,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
