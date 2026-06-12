import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/product_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ExpiryNotificationService {
  ExpiryNotificationService._();

  static final ExpiryNotificationService instance =
      ExpiryNotificationService._();

  static const _legacyNotificationId = 4104;
  static const _channelId = 'expiry_alerts';
  static const _channelName = 'Avisos de caducidad';
  static const _channelDescription =
      'Avisos diarios de productos cerca de vencer.';
  static const _notificationHour = 10;
  static const _notificationMinute = 15;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ApiService _api = const ApiService();
  final AuthService _auth = const AuthService();

  bool _initialized = false;
  bool _checking = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin.cancel(_legacyNotificationId);

    _initialized = true;
  }

  Future<void> checkAndNotify() async {
    if (_checking || !_auth.hasActiveSession) return;

    _checking = true;
    try {
      await initialize();

      final userId = _auth.currentUserId;
      final prefs = await SharedPreferences.getInstance();
      await _cancelScheduledNotifications(userId, prefs);

      final products = await _api.fetchProducts(status: 'active');
      final scheduledNotifications = _buildSchedule(products);
      final scheduledIds = <String>[];

      for (final scheduledNotification in scheduledNotifications) {
        final id = _notificationId(userId, scheduledNotification.dateKey);
        await _plugin.zonedSchedule(
          id,
          _notificationTitle(scheduledNotification),
          _notificationBody(scheduledNotification),
          _asUtcSchedule(scheduledNotification.dateTime),
          _notificationDetails(scheduledNotification),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: scheduledNotification.dateKey,
        );
        scheduledIds.add(id.toString());
      }

      await prefs.setStringList(_scheduledIdsKey(userId), scheduledIds);
    } catch (_) {
      // Notification checks must never block normal app navigation.
    } finally {
      _checking = false;
    }
  }

  Future<void> cancelCurrentUserNotifications() async {
    if (!_auth.hasActiveSession) return;

    try {
      await initialize();
      final prefs = await SharedPreferences.getInstance();
      await _cancelScheduledNotifications(_auth.currentUserId, prefs);
      await _plugin.cancel(_legacyNotificationId);
    } catch (_) {
      // Sign out should continue even if Android rejects notification cleanup.
    }
  }

  List<_ScheduledExpiryNotification> _buildSchedule(
      List<ProductModel> products) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDate = <String, _ScheduledExpiryNotification>{};

    for (final product in products) {
      final expiryDate = _expiryDate(product);
      if (expiryDate == null || expiryDate.isBefore(today)) continue;

      final firstWarningDate = expiryDate.subtract(
        const Duration(days: ProductModel.expiryWarningDays),
      );
      var notificationDate =
          firstWarningDate.isBefore(today) ? today : firstWarningDate;

      while (!notificationDate.isAfter(expiryDate)) {
        final notificationDateTime = DateTime(
          notificationDate.year,
          notificationDate.month,
          notificationDate.day,
          _notificationHour,
          _notificationMinute,
        );

        if (notificationDateTime.isAfter(now)) {
          final dateKey = _dateKey(notificationDate);
          final daysLeft = expiryDate.difference(notificationDate).inDays;
          final scheduledNotification = byDate.putIfAbsent(
            dateKey,
            () => _ScheduledExpiryNotification(
              dateKey: dateKey,
              dateTime: notificationDateTime,
              products: [],
            ),
          );
          scheduledNotification.products.add(
            _ScheduledExpiryProduct(product: product, daysLeft: daysLeft),
          );
        }

        notificationDate = notificationDate.add(const Duration(days: 1));
      }
    }

    final notifications = byDate.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    for (final notification in notifications) {
      notification.products.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    }
    return notifications;
  }

  NotificationDetails _notificationDetails(
      _ScheduledExpiryNotification notification) {
    final body = _notificationBody(notification);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: _notificationTitle(notification),
          summaryText: 'FrigoCheck',
        ),
      ),
    );
  }

  String _notificationTitle(_ScheduledExpiryNotification notification) {
    const titles = [
      '🍚 Se te va a pasar el arroz',
      '🥘 Operacion rescate nevera',
      '👀 Tu nevera te mira fijamente',
      '🧊 Alerta fresquita',
      '🔥 Receta de emergencia',
    ];
    return titles[_stableHash(notification.dateKey) % titles.length];
  }

  String _notificationBody(_ScheduledExpiryNotification notification) {
    final products = notification.products;
    final names = products.take(3).map((item) => item.product.name).join(', ');
    final extraCount = products.length - 3;
    final suffix = extraCount > 0 ? ' y $extraCount mas' : '';
    final shortestDaysLeft = products.first.daysLeft;
    final dayText = _daysText(shortestDaysLeft);

    final variants = [
      '$names$suffix entran en zona naranja: $dayText. Dales salida antes de que se pongan dramaticos.',
      'Te voy a tener que recomendar una receta con $names$suffix. $dayText y contando.',
      '$names$suffix estan pidiendo plan: tortilla, salteado o lo que sea, pero pronto. $dayText.',
      'La nevera dice que $names$suffix no han venido a pagar alquiler. $dayText para decidir.',
      '$names$suffix estan en modo cuenta atras. $dayText. Hoy huele a receta salvavidas.',
    ];

    return variants[
        _stableHash('${notification.dateKey}-$names') % variants.length];
  }

  String _daysText(int days) {
    if (days == 0) return 'Vencen hoy';
    if (days == 1) return 'Queda 1 dia';
    return 'Quedan $days dias';
  }

  DateTime? _expiryDate(ProductModel product) {
    final rawDate = product.estimatedExpiryDate;
    if (rawDate == null) return null;
    final parsedDate = DateTime.tryParse(rawDate);
    if (parsedDate == null) return null;
    return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  }

  tz.TZDateTime _asUtcSchedule(DateTime localDateTime) {
    return tz.TZDateTime.from(localDateTime.toUtc(), tz.UTC);
  }

  Future<void> _cancelScheduledNotifications(
      String userId, SharedPreferences prefs) async {
    final scheduledIds = prefs.getStringList(_scheduledIdsKey(userId)) ?? [];
    for (final rawId in scheduledIds) {
      final id = int.tryParse(rawId);
      if (id != null) {
        await _plugin.cancel(id);
      }
    }
    await prefs.remove(_scheduledIdsKey(userId));
  }

  int _notificationId(String userId, String dateKey) {
    return 100000 + (_stableHash('$userId-$dateKey') % 1900000000);
  }

  int _stableHash(String value) {
    var hash = 5381;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash << 5) + hash) + codeUnit;
      hash &= 0x7fffffff;
    }
    return hash;
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _scheduledIdsKey(String userId) {
    return 'expiry-scheduled-notifications-$userId';
  }
}

class _ScheduledExpiryNotification {
  _ScheduledExpiryNotification({
    required this.dateKey,
    required this.dateTime,
    required this.products,
  });

  final String dateKey;
  final DateTime dateTime;
  final List<_ScheduledExpiryProduct> products;
}

class _ScheduledExpiryProduct {
  const _ScheduledExpiryProduct({
    required this.product,
    required this.daysLeft,
  });

  final ProductModel product;
  final int daysLeft;
}
