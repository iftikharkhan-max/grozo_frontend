import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/user_model.dart';
import '../services/api.dart';

class CartLine {
  final Product product;
  int qty;
  CartLine(this.product, this.qty);

  Map<String, dynamic> toJson() => {'product': product.toJson(), 'qty': qty};
  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(Product.fromJson(j['product']), j['qty'] ?? 1);
}

/// App-wide state: session, language, cart and favorites. Persisted so the
/// customer stays logged in and keeps their cart after closing the app.
class AppState extends ChangeNotifier {
  static const _secure = FlutterSecureStorage();
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kLang = 'language';
  static const _kCart = 'cart';

  SharedPreferences? _prefs;

  UserModel? user;
  String language = 'en';
  final Map<int, CartLine> _cart = {};
  final Set<int> favoriteIds = {};

  /// Bumped only after the server has confirmed a favorites change, so lists
  /// reload once the change is actually saved.
  int favoritesRevision = 0;

  /// Bumped when an order is placed, cancelled or received, so "My Orders" reloads.
  int ordersRevision = 0;
  void ordersChanged() {
    ordersRevision++;
    notifyListeners();
    refreshUnread();
  }

  /// Unread in-app notifications (bell badge). Customers only.
  int unreadNotifications = 0;

  Future<void> refreshUnread() async {
    if (!isLoggedIn || !user!.isCustomer) return;
    final res = await Api.get('/me/notifications/unread-count');
    if (res.ok && res.data is Map) {
      final n = (res.data['unread'] as num?)?.toInt() ?? 0;
      if (n != unreadNotifications) {
        unreadNotifications = n;
        notifyListeners();
      }
    }
  }

  /// Set when the server ends the session; the UI shows a message once.
  bool sessionExpired = false;

  bool get isLoggedIn => user != null;
  bool get isUrdu => language == 'ur';

  // ---------- Startup ----------

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    language = _prefs!.getString(_kLang) ?? 'en';

    final cartJson = _prefs!.getString(_kCart);
    if (cartJson != null) {
      try {
        for (final l in (jsonDecode(cartJson) as List)) {
          final line = CartLine.fromJson(l);
          _cart[line.product.id] = line;
        }
      } catch (_) {}
    }

    try {
      final token = await _secure.read(key: _kToken);
      final userJson = await _secure.read(key: _kUser);
      if (token != null && userJson != null) {
        Api.token = token;
        user = UserModel.fromJson(jsonDecode(userJson));
      }
    } catch (_) {
      // Unreadable secure storage (e.g. after a backup restore): start logged out.
      await _secure.deleteAll();
    }

    Api.onSessionExpired = _handleSessionExpired;
    if (isLoggedIn) {
      refreshProfile();
      loadFavorites();
      refreshUnread();
    }
  }

  // ---------- Session ----------

  Future<ApiResult> login(String email, String password) async {
    final res = await Api.post('/auth/login', {'email': email.trim(), 'password': password});
    if (res.ok) await _startSession(res.data['token'], res.data);
    return res;
  }

  Future<ApiResult> register({required String name, required String email, required String password, String? mobile}) async {
    final res = await Api.post('/auth/register', {'name': name, 'email': email.trim(), 'password': password, 'mobile': mobile});
    if (res.ok) await _startSession(res.data['token'], res.data['user']);
    return res;
  }

  Future<void> _startSession(String token, Map<String, dynamic> userJson) async {
    Api.token = token;
    user = UserModel.fromJson(userJson);
    sessionExpired = false;
    await _secure.write(key: _kToken, value: token);
    await _secure.write(key: _kUser, value: jsonEncode(user!.toJson()));
    // A language chosen before logging in wins over the stored account preference.
    if (user!.language != language) Api.put('/auth/me', {'language': language});
    notifyListeners();
    loadFavorites();
    refreshUnread();
  }

  Future<void> refreshProfile() async {
    final res = await Api.get('/auth/me');
    if (res.ok && isLoggedIn) {
      user = UserModel.fromJson(res.data);
      await _secure.write(key: _kUser, value: jsonEncode(user!.toJson()));
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (Api.token != null) await Api.post('/auth/logout');
    await signOutLocally();
  }

  void _handleSessionExpired() {
    sessionExpired = true;
    signOutLocally();
  }

  /// Forgets the session on this device without calling the server
  /// (e.g. after the account was deleted).
  Future<void> signOutLocally() async {
    Api.token = null;
    user = null;
    favoriteIds.clear();
    unreadNotifications = 0;
    await _secure.delete(key: _kToken);
    await _secure.delete(key: _kUser);
    notifyListeners();
  }

  /// Stores a fresh token issued by the server (e.g. after a password change).
  Future<void> replaceToken(String token) async {
    Api.token = token;
    await _secure.write(key: _kToken, value: token);
  }

  void setUser(UserModel updated) {
    user = updated;
    _secure.write(key: _kUser, value: jsonEncode(updated.toJson()));
    notifyListeners();
  }

  // ---------- Language ----------

  Future<void> setLanguage(String lang) async {
    if (lang == language) return;
    language = lang;
    await _prefs?.setString(_kLang, lang);
    notifyListeners();
    if (isLoggedIn) Api.put('/auth/me', {'language': lang});
  }

  // ---------- Cart ----------

  List<CartLine> get cartLines => _cart.values.toList();
  int get cartCount => _cart.values.fold(0, (s, l) => s + l.qty);
  int qtyInCart(int productId) => _cart[productId]?.qty ?? 0;

  /// Estimated items total from the last known prices; the server re-checks at checkout.
  double get cartEstimate => _cart.values.fold(0.0, (s, l) => s + l.product.finalPrice * l.qty);

  /// Returns false when the quantity limit (stock / per-order max) was reached.
  bool addToCart(Product p, {int qty = 1}) {
    if (!p.available) return false;
    final current = _cart[p.id]?.qty ?? 0;
    final limit = p.maxQty;
    final next = limit == null ? current + qty : (current + qty).clamp(0, limit);
    if (next == current) return false;
    _cart[p.id] = CartLine(p, next);
    _saveCart();
    return next == current + qty;
  }

  void setQty(int productId, int qty) {
    final line = _cart[productId];
    if (line == null) return;
    if (qty <= 0) {
      _cart.remove(productId);
    } else {
      final limit = line.product.maxQty;
      line.qty = limit == null ? qty : qty.clamp(1, limit);
    }
    _saveCart();
  }

  /// Replaces the stored product details with fresh ones from the server.
  void refreshCartProducts(List<Product> fresh) {
    for (final p in fresh) {
      final line = _cart[p.id];
      if (line != null) _cart[p.id] = CartLine(p, line.qty);
    }
    _saveCart();
  }

  void removeFromCart(int productId) => setQty(productId, 0);

  void clearCart() {
    _cart.clear();
    _saveCart();
  }

  void _saveCart() {
    _prefs?.setString(_kCart, jsonEncode(_cart.values.map((l) => l.toJson()).toList()));
    notifyListeners();
  }

  // ---------- Favorites ----------

  Future<void> loadFavorites() async {
    final res = await Api.get('/me/favorites');
    if (res.ok && res.data is List) {
      favoriteIds
        ..clear()
        ..addAll((res.data as List).map((p) => (p['id'] as num).toInt()));
      notifyListeners();
    }
  }

  bool isFavorite(int productId) => favoriteIds.contains(productId);

  /// Optimistically toggles; reverts if the server call fails.
  Future<bool> toggleFavorite(int productId) async {
    final adding = !favoriteIds.contains(productId);
    adding ? favoriteIds.add(productId) : favoriteIds.remove(productId);
    notifyListeners();
    final res = adding ? await Api.post('/me/favorites/$productId') : await Api.delete('/me/favorites/$productId');
    if (res.ok) {
      favoritesRevision++;
    } else {
      adding ? favoriteIds.remove(productId) : favoriteIds.add(productId);
    }
    notifyListeners();
    return res.ok;
  }
}
