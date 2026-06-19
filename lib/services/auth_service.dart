import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config/google_auth_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal();

  static const _driveFileScope = 'https://www.googleapis.com/auth/drive.file';
  static const _logPath = 'debug-f718fe.log';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId:
        GoogleAuthConfig.isConfigured ? GoogleAuthConfig.webClientId : null,
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isSignedIn => currentUser != null;

  void _agentLog(
    String location,
    String message,
    Map<String, dynamic> data,
    String hypothesisId,
  ) {
    // #region agent log
    try {
      final payload = jsonEncode({
        'sessionId': 'f718fe',
        'location': location,
        'message': message,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'hypothesisId': hypothesisId,
      });
      File(_logPath).writeAsStringSync('$payload\n', mode: FileMode.append);
    } catch (_) {}
    // #endregion
  }

  Future<User?> signInWithGoogle() async {
    _agentLog(
      'auth_service.dart:signInWithGoogle:start',
      'signIn started',
      {'isConfigured': GoogleAuthConfig.isConfigured},
      'A',
    );
    try {
      if (!GoogleAuthConfig.isConfigured) {
        throw Exception(
          '尚未設定 Web Client ID。請到 Firebase Console → Authentication → Google '
          '複製 Web client ID，填入 lib/config/google_auth_config.dart，'
          '並加入 SHA-1 指紋後重新下載 google-services.json。',
        );
      }

      final googleUser = await googleSignIn.signIn();
      _agentLog(
        'auth_service.dart:signInWithGoogle:afterPicker',
        'account picker returned',
        {
          'cancelled': googleUser == null,
          'email': googleUser?.email,
        },
        'B',
      );
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      _agentLog(
        'auth_service.dart:signInWithGoogle:gotTokens',
        'got google auth tokens',
        {
          'hasIdToken': googleAuth.idToken != null,
          'hasAccessToken': googleAuth.accessToken != null,
        },
        'A',
      );

      if (googleAuth.idToken == null) {
        throw Exception(
          'Google 登入未取得 idToken。請在 Firebase Console 為 Android 應用程式加入 '
          'SHA-1：0C:AA:E9:64:DE:42:10:BE:87:1B:36:DE:E9:33:7B:BA:B8:3C:C7:BA，'
          '並確認 google_auth_config.dart 的 Web Client ID 正確。',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      _agentLog(
        'auth_service.dart:signInWithGoogle:firebaseDone',
        'firebase signIn done',
        {'uid': userCredential.user?.uid},
        'A',
      );

      final hasDriveScope = await googleSignIn.requestScopes([_driveFileScope]);
      _agentLog(
        'auth_service.dart:signInWithGoogle:driveScope',
        'drive scope requested',
        {'granted': hasDriveScope},
        'D',
      );
      if (!hasDriveScope) {
        throw Exception('需要 Google Drive 權限才能上傳圖片');
      }

      return userCredential.user;
    } on FirebaseAuthException catch (e, stack) {
      debugPrint('FirebaseAuthException: ${e.code} ${e.message}\n$stack');
      _agentLog(
        'auth_service.dart:signInWithGoogle:firebaseError',
        'firebase auth error',
        {'code': e.code, 'message': e.message},
        'A',
      );
      throw Exception('Firebase 登入失敗：${e.message ?? e.code}');
    } catch (e, stack) {
      debugPrint('Google sign-in error: $e\n$stack');
      _agentLog(
        'auth_service.dart:signInWithGoogle:error',
        'signIn error',
        {'error': e.toString()},
        'B',
      );
      if (e is Exception) rethrow;
      throw Exception('Google 登入失敗：$e');
    }
  }

  Future<void> signOut() async {
    await googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<User?> ensureSignedIn() async {
    if (isSignedIn) return currentUser;
    return signInWithGoogle();
  }
}
