import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Notification-only messages: the OS shows them automatically.
  // Data-only messages that need Firebase APIs would require initializeApp() here.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenRefreshSub;
  String? _activeUid;

  static bool get fcmSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Call once after the user is authenticated.
  /// Errors are caught and logged — notification failure is non-critical.
  Future<void> initialize({required String uid}) async {
    if (!fcmSupported || _activeUid == uid) return;
    _activeUid = uid;
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      // iOS: show notifications while the app is in foreground.
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _fcm.getToken();
      if (token != null) await _saveToken(uid, token);

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) async {
        try {
          await _saveToken(uid, newToken);
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[NotificationService] FCM init failed (non-critical): $e');
    }
  }

  /// Call before sign-out so the Firestore write succeeds while auth is active.
  Future<void> dispose({required String uid}) async {
    if (_activeUid == null) return; // already disposed
    _activeUid = null;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    if (!fcmSupported) return;
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _db.collection('user_devices').doc(uid).set({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[NotificationService] token removal failed: $e');
    }
    try {
      await _fcm.deleteToken();
    } catch (_) {}
  }

  Future<void> _saveToken(String uid, String token) async {
    final data = {
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (var attempt = 0; attempt < 4; attempt++) {
      if (_activeUid != uid) return;
      try {
        await _db
            .collection('user_devices')
            .doc(uid)
            .set(data, SetOptions(merge: true));
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || attempt == 3) {
          debugPrint('[NotificationService] saveToken failed: $e');
          return;
        }
        await Future.delayed(Duration(seconds: 2 << attempt)); // 2, 4, 8 s
      }
    }
  }
}
