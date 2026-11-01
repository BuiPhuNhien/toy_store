import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
