import 'package:flutter/foundation.dart';

import 'api_client.dart';

class CartLine {
  CartLine({
    required this.product,
    required this.variantId,
    required this.quantity,
  });

  final Map<String, dynamic> product;
  final int variantId;
  int quantity;

  double get price {
    final variants = product['productVariants'];
    if (variants is List) {
      for (final item in variants.whereType<Map>()) {
        if (_int(item['variantId']) == variantId) {
          return _double(item['price'] ?? item['sellingPrice']);
        }
      }
    }
    return _double(product['basePrice']);
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
      ]);
      products = _asMapList(results[0])
          .where(
            (product) =>
                _int(product['status']) != 0 && _int(product['status']) != 3,
          )
          .toList();
      categories = _asMapList(results[1]);
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

  Future<void> addToCart(Map<String, dynamic> product) async {
    var selected = product;
    var variants = _asMapList(selected['productVariants']);
    if (variants.isEmpty) {
      final detailed = await api.get('Product/${product['productId']}');
      selected = _asMap(detailed);
      variants = _asMapList(selected['productVariants']);
    }

    final variantId = variants.isEmpty
        ? _int(selected['productId'])
        : _int(variants.first['variantId']);
    final existing = cart.where((line) => line.variantId == variantId);
    if (existing.isNotEmpty) {
      existing.first.quantity++;
    } else {
      cart.add(CartLine(product: selected, variantId: variantId, quantity: 1));
    }
    notifyListeners();
  }

  void updateCartQuantity(CartLine line, int change) {
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
    if (_int(profile['customerId']) <= 0) {
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
    switch (method) {
      case 'POST':
        return api.post(path, body);
      case 'PUT':
        return api.put(path, body);
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

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
