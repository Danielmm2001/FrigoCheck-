import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ExpiryNotificationService {
  ExpiryNotificationService._();

  static final ExpiryNotificationService instance =
      ExpiryNotificationService._();

  static const _notificationId = 4104;
  static const _channelId = 'expiry_alerts';
  static const _channelName = 'Avisos de caducidad';
  static const _channelDescription =
      'Avisos diarios de productos cerca de vencer.';

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

    _initialized = true;
  }

  Future<void> checkAndNotify() async {
    if (_checking || !_auth.hasActiveSession) return;

    _checking = true;
    try {
      await initialize();

      final products = await _api.fetchProducts(status: 'active');
      final warningProducts = products.where((product) {
        return product.isExpiringSoon;
      }).toList()
        ..sort((a, b) => (a.daysLeft ?? 9999).compareTo(b.daysLeft ?? 9999));

      if (warningProducts.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final todayKey = _todayKey();
      final userId = _auth.currentUserId;
      final pendingProducts = warningProducts.where((product) {
        return prefs.getBool(_preferenceKey(userId, product.id, todayKey)) !=
            true;
      }).toList();

      if (pendingProducts.isEmpty) return;

      await _plugin.show(
        _notificationId,
        'Revisa tu nevera',
        _notificationBody(pendingProducts),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );

      for (final product in pendingProducts) {
        await prefs.setBool(_preferenceKey(userId, product.id, todayKey), true);
      }
    } catch (_) {
      // Notification checks must never block normal app navigation.
    } finally {
      _checking = false;
    }
  }

  String _notificationBody(List<ProductModel> products) {
    if (products.length == 1) {
      final product = products.first;
      return '${product.name} ${_expiryPhrase(product)}.';
    }

    final names = products.take(3).map((product) => product.name).join(', ');
    final remaining = products.length - 3;
    if (remaining > 0) {
      return '${products.length} productos necesitan revision: $names y $remaining mas.';
    }
    return '${products.length} productos necesitan revision: $names.';
  }

  String _expiryPhrase(ProductModel product) {
    final days = product.daysLeft;
    if (days == 0) return 'vence hoy';
    if (days == 1) return 'vence en 1 dia';
    return 'vence en ${product.daysLabel.toLowerCase()}';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _preferenceKey(String userId, String productId, String todayKey) {
    return 'expiry-notification-$userId-$productId-$todayKey';
  }
}
