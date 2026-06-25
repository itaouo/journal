import 'package:flutter/material.dart';

import '../models/diary.dart';
import '../services/backup_settings_service.dart';
import '../services/diary_lock_service.dart';
import '../widgets/pin_entry_dialog.dart';
import '../widgets/pin_setup_dialog.dart';

Future<bool> ensureLockedDiaryUnlocked(
  BuildContext context, {
  required Diary diary,
  required DiaryLockService lockService,
  required LockPinPromptMode pinPromptMode,
}) async {
  if (!diary.isLocked) {
    return true;
  }

  if (lockService.shouldSkipPinPrompt(pinPromptMode)) {
    return true;
  }

  if (!await lockService.hasPin()) {
    if (!context.mounted) return false;
    final setupPin = await showPinSetupDialog(
      context,
      title: '設定 PIN',
      subtitle: '此日記已上鎖，請先設定本機 PIN 才能開啟',
    );
    if (setupPin == null) return false;
    await lockService.setPin(setupPin);
    if (pinPromptMode == LockPinPromptMode.oncePerAppSession) {
      lockService.markSessionUnlocked();
    }
    return true;
  }

  if (!context.mounted) return false;
  final pin = await showPinEntryDialog(
    context,
    title: '輸入 PIN',
    subtitle: '此日記已上鎖',
  );
  if (pin == null) return false;

  if (!await lockService.verifyPin(pin, pinPromptMode: pinPromptMode)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN 錯誤')),
      );
    }
    return false;
  }

  return true;
}
