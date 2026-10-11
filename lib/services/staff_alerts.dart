import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// New-order alerts for Managers and Riders (spec 9).
///
/// The server writes an alert for each manager when an order arrives and for a
/// rider when an order is given to them. While the Manager/Rider app is open or
/// in the background, this checks for new ones every [interval] and shows a
/// phone notification with sound and vibration (order number, summary, what to
/// do), then lets the screen refresh its lists.
///
/// When Android has fully closed the app, alerts appear on the next start; push
/// delivery to a closed app needs Firebase Cloud Messaging (not set up yet).
class StaffAlerts {
  StaffAlerts({required this.userId, required this.onNewAlerts});

  final int userId;

  /// Called after new alerts arrived, e.g. to reload the order lists.
  final VoidCallback onNewAlerts;

  static const interval = Duration(seconds: 20);
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Tests turn the phone notification off (there is no platform in tests).
  @visibleForTesting
  static bool showPhoneNotifications = true;

  /// Alerts shown in this session, newest last (tests read it).
  @visibleForTesting
  static final shown = <Map<String, dynamic>>[];

  static const _channel = AndroidNotificationDetails(
    'new_orders',
    'New orders',
    channelDescription: 'New orders and deliveries for managers and riders',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    category: AndroidNotificationCategory.message,
    ticker: 'New order',
  );

  Timer? _timer;
  int? _lastSeenId;
  bool _checking = false;
  String get _prefKey => 'staff_alerts_last_seen_$userId';

  Future<void> start() async {
    await _init();
    final prefs = await SharedPreferences.getInstance();
    _lastSeenId = prefs.getInt(_prefKey);
    await check();
    _timer = Timer.periodic(interval, (_) => check());
  }

  void stop() => _timer?.cancel();

  static Future<void> _init() async {
    if (_ready || !showPhoneNotifications) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/launcher_icon'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      // Android 13+ asks the user once; without it alerts stay silent.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('StaffAlerts init failed: $e');
    }
  }

  /// Looks for alerts newer than the last one seen.
  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      final res = await Api.get('/me/notifications');
      if (!res.ok || res.data is! List) return;
      final alerts = List<Map<String, dynamic>>.from(res.data)
          .where((n) => n['type'] == 'order')
          .toList()
        ..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
      if (alerts.isEmpty) {
        // Nothing yet: every alert from now on is new.
        if (_lastSeenId == null) await _remember(0);
        return;
      }
      final newestId = (alerts.last['id'] as num).toInt();

      // First run on this phone: don't replay old alerts, just remember them.
      if (_lastSeenId == null) {
        await _remember(newestId);
        return;
      }
      final fresh = alerts
          .where((n) => (n['id'] as num) > _lastSeenId! && n['read_at'] == null)
          .toList();
      if (newestId > _lastSeenId!) await _remember(newestId);
      if (fresh.isEmpty) return;

      for (final n in fresh) {
        shown.add(n);
        if (showPhoneNotifications && _ready) {
          await _plugin.show(
            id: (n['id'] as num).toInt(),
            title: '${n['title']}',
            body: '${n['body'] ?? ''}',
            notificationDetails: const NotificationDetails(
                android: _channel,
                iOS: DarwinNotificationDetails(presentSound: true)),
            payload: '${n['order_id'] ?? ''}',
          );
        }
      }
      onNewAlerts();
    } finally {
      _checking = false;
    }
  }

  Future<void> _remember(int id) async {
    _lastSeenId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, id);
  }
}
