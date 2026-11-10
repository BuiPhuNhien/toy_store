import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toy_store/core/api_client.dart';
import 'package:toy_store/core/app_state.dart';
import 'package:toy_store/ui/app_screens.dart';

void main() {
  testWidgets('login screen can switch to account registration', (
    tester,
  ) async {
    final state = AppState(ApiClient());
    addTearDown(() {
      state.api.close();
      state.dispose();
    });

    await tester.pumpWidget(MaterialApp(home: LoginScreen(state: state)));

    expect(find.text('Chào mừng đến ToyStore'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);

    await tester.tap(find.text('Chưa có tài khoản? Đăng ký ngay'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo tài khoản mới'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
  });

  testWidgets('login screen can open API config dialog and display options', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final state = AppState(ApiClient());
    addTearDown(() {
      state.api.close();
      state.dispose();
    });

    await tester.pumpWidget(MaterialApp(home: LoginScreen(state: state)));

    // Find and tap the API settings button
    final configBtn = find.byIcon(Icons.settings_ethernet);
    expect(configBtn, findsOneWidget);
    await tester.tap(configBtn);
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Cấu hình Server API'), findsWidgets);
    expect(find.text('Localhost (Windows)'), findsOneWidget);
    expect(find.text('Android Emulator (10.0.2.2)'), findsOneWidget);
    expect(find.text('Kiểm tra kết nối (Ping)'), findsOneWidget);
  });

  test('AppState cart calculations with variants and stock limits', () async {
    final state = AppState(ApiClient());
    addTearDown(() {
      state.api.close();
      state.dispose();
    });

    final product = {
      'id': 101,
      'name': 'Bộ đồ chơi xếp hình Lego Classic',
      'price': 250000.0,
      'stock': 10,
      'productVariants': [
        {
          'variantId': 501,
          'variantName': 'Hộp 500 chi tiết',
          'price': 450000.0,
          'stockQuantity': 5,
          'sku': 'LEGO-500',
        },
      ],
    };

    // Add product without explicit variant (falls back to product id/price)
    await state.addToCart(product, variantId: 101, quantity: 2);
    expect(state.cart.length, 1);
    expect(state.cart.first.quantity, 2);
    expect(state.cartTotal, 500000.0);

    // Add same product with a variant
    await state.addToCart(
      product,
      variantId: 501,
      variantName: 'Hộp 500 chi tiết',
      sku: 'LEGO-500',
      quantity: 1,
    );
    expect(state.cart.length, 2);
    expect(state.cartTotal, 500000.0 + 450000.0);

    // Update quantity of the variant line by +2
    state.updateCartQuantity(state.cart[1], 2);
    expect(state.cart[1].quantity, 3);
    expect(state.cartTotal, 500000.0 + 3 * 450000.0);

    // Remove first line by reducing its quantity to 0
    state.updateCartQuantity(state.cart.first, -state.cart.first.quantity);
    expect(state.cart.length, 1);
    expect(state.cartTotal, 3 * 450000.0);

    // Clear cart
    state.clearCart();
    expect(state.cart.isEmpty, true);
    expect(state.cartTotal, 0.0);
  });

  test('ApiClient URL helper functions', () {
    final api = ApiClient();
    addTearDown(api.close);

    // Default baseUrl
    expect(api.baseUrl.isNotEmpty, true);

    // Check absoluteAssetUrl formatting
    expect(api.absoluteAssetUrl(''), '');
    expect(
      api.absoluteAssetUrl('https://example.com/image.jpg'),
      'https://example.com/image.jpg',
    );
    expect(
      api
          .absoluteAssetUrl('/uploads/products/lego.png')
          .endsWith('/uploads/products/lego.png'),
      true,
    );
  });

  test('Android emulator uses the host API address by default', () {
    final api = ApiClient(platform: TargetPlatform.android);
    addTearDown(api.close);

    expect(api.baseUrl, 'http://10.0.2.2:5225/api');
  });

  test('health check accepts any successful API response', () async {
    final api = ApiClient(
      client: MockClient((request) async {
        expect(request.url.path, '/api/Health');
        return http.Response('{"status":"ok"}', 200);
      }),
    );
    addTearDown(api.close);

    expect(await api.checkHealth(), isTrue);
  });

  test('product stock is read from aggregate or variant API fields', () {
    expect(
      productAvailableStock({
        'ProductVariants': [
          {'AvailableQuantity': 4, 'quantity': 10},
          {'availableQuantity': 6},
        ],
      }),
      10,
    );
    expect(
      productAvailableStock({
        'productVariants': [
          {'availableQuantity': 8},
        ],
      }),
      8,
    );
    expect(productAvailableStock({'stockQuantity': 0}), 0);
    expect(productAvailableStock({'productVariants': []}), isNull);
  });

  test(
    'product price falls back to the API variant price when base is zero',
    () {
      expect(
        productDisplayPrice({
          'basePrice': 0,
          'productVariants': [
            {'price': 0},
            {'price': 125000},
            {'sellingPrice': 99000},
          ],
        }),
        99000,
      );
      expect(productDisplayPrice({'BasePrice': 150000}), 150000);
      expect(
        CartLine(
          product: {
            'basePrice': 0,
            'productVariants': [
              {'variantId': 5, 'price': 75000},
            ],
          },
          variantId: 5,
          quantity: 1,
        ).price,
        75000,
      );
    },
  );
}
