import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  static bool get fcmSupported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Call once after the user is authenticated.
  Future<void> initialize({required String uid}) async {
    if (!fcmSupported) return;

    // Register background handler (safe to call multiple times).
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+ and iOS).
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Get and persist the current token.
    final token = await _fcm.getToken();
    if (token != null) await _saveToken(uid, token);

    // Refresh token when it changes.
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _fcm.onTokenRefresh.listen(
      (newToken) => _saveToken(uid, newToken),
    );

    // When app is in foreground and a message arrives, show a simple snack
    // or let the OS handle it — nothing special needed here.
    _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen((_) {});
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
