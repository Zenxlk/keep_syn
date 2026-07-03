import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

/// Top-level handler required by firebase_messaging for background messages.
/// Must be a top-level function (not a method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this fires.
  // Nothing extra needed — the OS shows the notification automatically.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;

  // macOS requiere entitlement com.apple.developer.aps-environment + APNS
  // configurado en Firebase Console. Hasta que esté listo, solo Android/iOS/web.
  static bool get fcmSupported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS;

  /// Call once after the user is authenticated.
  /// Errors are caught and logged — notification failure is non-critical.
  Future<void> initialize({required String uid}) async {
    if (!fcmSupported) return;
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await _fcm.getToken();
      if (token != null) await _saveToken(uid, token);

      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen(
        (newToken) => _saveToken(uid, newToken),
      );

      _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((_) {});
    } catch (e) {
      debugPrint('[NotificationService] FCM init failed (non-critical): $e');
    }
  }

  /// Call on logout to remove this device's token from Firestore.
  Future<void> dispose({required String uid}) async {
    _foregroundSub?.cancel();
    _tokenRefreshSub?.cancel();
    if (!fcmSupported) return;
    final token = await _fcm.getToken();
    if (token != null) {
      await _db.collection('user_devices').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    await _db.collection('user_devices').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
