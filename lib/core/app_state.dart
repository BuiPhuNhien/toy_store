import 'package:flutter/foundation.dart';

import 'api_client.dart';

class CartLine {
  CartLine({
    required this.product,
    required this.variantId,
    required this.quantity,
    this.variantName,
    this.sku,
  });

  final Map<String, dynamic> product;
  final int variantId;
  int quantity;
  final String? variantName;
  final String? sku;

  Map<String, dynamic>? get selectedVariant {
    final variants =
        product['productVariants'] ??
        product['variants'] ??
        product['Variants'];
    if (variants is List) {
      for (final item in variants.whereType<Map>()) {
        if (_int(item['variantId'] ?? item['id'] ?? item['VariantId']) ==
            variantId) {
          return item is Map<String, dynamic>
              ? item
              : item.map((k, v) => MapEntry('$k', v));
        }
      }
    }
    return null;
  }

  int get maxStock {
    final v = selectedVariant;
    if (v != null) {
      return variantAvailableStock(v) ?? 99;
    }
    return productAvailableStock(product) ?? 99;
  }

  double get price {
    final v = selectedVariant;
    if (v != null) {
      final price = variantPrice(v);
      if (price > 0) return price;
    }
    return productDisplayPrice(product);
  }

  double get total => price * quantity;
}

class AppState extends ChangeNotifier {
  AppState(this.api);

  final ApiClient api;
  bool initialized = false;
  bool busy = false;
  String? error;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> brands = [];
  List<Map<String, dynamic>> orders = [];
  List<CartLine> cart = [];
  Map<String, dynamic> profile = {};

  Map<String, dynamic>? get session => api.session;
  String get role => (session?['role'] ?? '').toString();
  String get fullName => (session?['fullName'] ?? 'Khách hàng').toString();
  bool get isCustomer => role.toLowerCase() == 'customer';
  bool get isShipper => role.toLowerCase() == 'shipper';
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get canManageInventory =>
      const {'admin', 'manager'}.contains(role.toLowerCase());
  bool get isStaff =>
      const {'admin', 'manager', 'staff'}.contains(role.toLowerCase());
  int get cartCount => cart.fold(0, (total, line) => total + line.quantity);
  double get cartTotal => cart.fold(0, (total, line) => total + line.total);

  Future<void> initialize() async {
    await api.restoreSession();
    initialized = true;
    notifyListeners();
  }

  Future<void> updateApiBaseUrl(String newUrl) async {
    await api.updateBaseUrl(newUrl);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _setBusy(true);
    try {
      final result = await api.post('Auth/login', {
        'email': email.trim(),
        'password': password,
      });
      if (result is! Map<String, dynamic>) {
        throw const ApiException('Dữ liệu đăng nhập từ máy chủ không hợp lệ.');
      }
      await api.saveSession(result);
      error = null;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _setBusy(true);
    try {
      await api.post('Auth/register', {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phoneNumber': phone.trim(),
        'password': password,
      });
      await login(email, password);
    } finally {
      _setBusy(false);
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final result = await api.post('Auth/forgot-password', {
      'email': email.trim(),
    });
    return _asMap(result);
  }

  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
  }) async {
    await api.post('Auth/reset-password', {
      'email': email.trim(),
      'token': token.trim(),
      'newPassword': password,
      'confirmPassword': password,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await api.post('Auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': newPassword,
    });
  }

  Future<void> logout() async {
    try {
      if (session != null) await api.post('Auth/logout');
    } finally {
      await api.clearSession();
      products = [];
      categories = [];
      brands = [];
      orders = [];
      cart = [];
      profile = {};
      error = null;
      notifyListeners();
    }
  }

  Future<void> loadCatalog() async {
    _setBusy(true);
    try {
      final results = await Future.wait([
        api.get('Product'),
        api.get('Category'),
        api.get('Brand'),
      ]);
      products = _asMapList(results[0]).where((p) {
        final s = (p['status'] ?? p['Status'])?.toString().toLowerCase();
        return s != '3' && s != '5' && s != 'inactive' && s != 'deleted';
      }).toList();
      categories = _asMapList(results[1]);
      brands = _asMapList(results[2]);
      error = null;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> loadProfile() async {
    final result = await api.get('Customer/profile');
    profile = _asMap(result);
    notifyListeners();
  }

  Future<void> saveProfile({
    required String fullName,
    required String phone,
    String? dateOfBirth,
    int? gender,
  }) async {
    final body = <String, dynamic>{
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'dateOfBirth': dateOfBirth,
      'gender': gender,
    };
    final result = await api.put('Customer/profile', body);
    profile = _asMap(result);
    notifyListeners();
  }

  Future<void> loadOrders() async {
    final path = isCustomer ? 'Order/mine' : 'Order';
    orders = _asMapList(await api.get(path));
    notifyListeners();
  }

  Future<void> addToCart(
    Map<String, dynamic> product, {
    int? variantId,
    int quantity = 1,
    String? variantName,
    String? sku,
  }) async {
    var selected = product;
    final id = product['productId'] ?? product['id'] ?? product['ProductId'];

    var variants = _asMapList(
      selected['productVariants'] ??
          selected['variants'] ??
          selected['Variants'],
    );
    if (variants.isEmpty && id != null) {
      try {
        final detailed = await api.get('Product/$id');
        selected = _asMap(detailed);
        variants = _asMapList(
          selected['productVariants'] ??
              selected['variants'] ??
              selected['Variants'],
        );
      } catch (_) {}
    }

    final targetVariantId =
        variantId ??
        (variants.isEmpty
            ? _int(id)
            : _int(
                variants.first['variantId'] ??
                    variants.first['id'] ??
                    variants.first['VariantId'],
              ));

    final existing = cart.where((line) => line.variantId == targetVariantId);
    if (existing.isNotEmpty) {
      final line = existing.first;
      final max = line.maxStock;
      if (max > 0 && line.quantity + quantity > max) {
        throw ApiException(
          'Số lượng trong giỏ (${line.quantity + quantity}) vượt quá tồn kho khả dụng ($max).',
        );
      }
      line.quantity += quantity;
    } else {
      final newLine = CartLine(
        product: selected,
        variantId: targetVariantId,
        quantity: quantity,
        variantName: variantName,
        sku: sku,
      );
      final max = newLine.maxStock;
      if (max > 0 && quantity > max) {
        throw ApiException(
          'Số lượng yêu cầu ($quantity) vượt quá tồn kho khả dụng ($max).',
        );
      }
      cart.add(newLine);
    }
    notifyListeners();
  }

  void updateCartQuantity(CartLine line, int change) {
    if (change > 0) {
      final max = line.maxStock;
      if (max > 0 && line.quantity + change > max) {
        throw ApiException('Đã đạt số lượng tồn kho tối đa ($max).');
      }
    }
    line.quantity += change;
    if (line.quantity <= 0) cart.remove(line);
    notifyListeners();
  }

  void clearCart() {
    cart = [];
    notifyListeners();
  }

  Future<Map<String, dynamic>> checkout({
    required String receiverName,
    required String receiverPhone,
    required String address,
    required int paymentMethod,
    String? voucherCode,
    String? note,
  }) async {
    if (cart.isEmpty) {
      throw const ApiException('Giỏ hàng đang trống.');
    }
    if (_int(profile['customerId'] ?? profile['id'] ?? profile['CustomerId']) <=
        0) {
      throw const ApiException(
        'Vui lòng lưu hồ sơ khách hàng trước khi đặt hàng.',
      );
    }

    final result = await api.post('Order', {
      'note': note ?? '',
      'paymentMethod': paymentMethod,
      'voucherCode': voucherCode,
      'shipping': {
        'receiverName': receiverName.trim(),
        'receiverPhone': receiverPhone.trim(),
        'address': address.trim(),
        'trackingCode': null,
        'shippingMethod': 0,
        'shippingFee': 0,
        'estimatedDeliveryAt': null,
      },
      'orderDetails': cart
          .map(
            (line) => {'variantId': line.variantId, 'quantity': line.quantity},
          )
          .toList(),
    });
    return _asMap(result);
  }

  Future<Map<String, dynamic>> createZaloPayPayment(int orderId) async =>
      _asMap(await api.post('ZaloPay/orders/$orderId/create'));

  Future<Map<String, dynamic>> getZaloPayPaymentStatus(int orderId) async =>
      _asMap(await api.get('ZaloPay/orders/$orderId/status'));

  Future<Map<String, dynamic>> confirmSandboxPayment(int orderId) async =>
      _asMap(await api.post('ZaloPay/orders/$orderId/confirm-sandbox-payment'));

  Future<dynamic> loadApiData(String path) => api.get(path);

  Future<dynamic> performApiAction(String method, String path, {Object? body}) {
    switch (method.toUpperCase()) {
      case 'POST':
        return api.post(path, body);
      case 'PUT':
        return api.put(path, body);
      case 'PATCH':
        return api.patch(path, body);
      case 'DELETE':
        return api.delete(path);
      default:
        return api.get(path);
    }
  }

  void _setBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map>().map(_asMap).toList();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    return {};
  }
}

int? productAvailableStock(Map<String, dynamic> product) {
  final stock = variantAvailableStock(product);
  if (stock != null) return stock;

  final variants =
      _field(product, 'productVariants') ?? _field(product, 'variants');
  if (variants is! List) return null;

  var total = 0;
  var hasKnownStock = false;
  for (final variant in variants.whereType<Map>()) {
    final normalized = variant.map((key, value) => MapEntry('$key', value));
    final variantStock = variantAvailableStock(normalized);
    if (variantStock == null) continue;
    total += variantStock;
    hasKnownStock = true;
  }
  return hasKnownStock ? total : null;
}

int? variantAvailableStock(Map<String, dynamic> item) {
  for (final key in const [
    'availableQuantity',
    'stockQuantity',
    'totalStock',
    'stock',
    'quantity',
  ]) {
    final value = _field(item, key);
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

double productDisplayPrice(Map<String, dynamic> product) {
  final price = _positiveAmount(
    _field(product, 'basePrice') ?? _field(product, 'price'),
  );
  if (price > 0) return price;

  final variants =
      _field(product, 'productVariants') ?? _field(product, 'variants');
  if (variants is! List) return 0;

  final prices = variants
      .whereType<Map>()
      .map((variant) => variant.map((key, value) => MapEntry('$key', value)))
      .map(variantPrice)
      .where((value) => value > 0)
      .toList();
  if (prices.isEmpty) return 0;
  return prices.reduce((a, b) => a < b ? a : b);
}

double variantPrice(Map<String, dynamic> variant) => _positiveAmount(
  _field(variant, 'price') ?? _field(variant, 'sellingPrice'),
);

double _positiveAmount(dynamic value) {
  final amount = value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? 0;
  return amount > 0 ? amount : 0;
}

dynamic _field(Map<String, dynamic> map, String key) {
  final normalizedKey = key.toLowerCase();
  for (final entry in map.entries) {
    if (entry.key.toLowerCase() == normalizedKey) return entry.value;
  }
  return null;
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
