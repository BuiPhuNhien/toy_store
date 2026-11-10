import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/api_client.dart';
import 'core/app_state.dart';
import 'ui/app_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(ToyStoreApp(state: AppState(ApiClient())));
}

class ToyStoreApp extends StatefulWidget {
  const ToyStoreApp({required this.state, super.key});

  final AppState state;

  @override
  State<ToyStoreApp> createState() => _ToyStoreAppState();
}

class _ToyStoreAppState extends State<ToyStoreApp> {
  late final Future<void> _initialization = _init();

  Future<void> _init() async {
    await widget.state.initialize();
    await Future.delayed(const Duration(seconds: 2)); // Giữ splash screen 2s
  }

  /// Trả về ThemeData phù hợp với vai trò đang đăng nhập:
  /// - Customer / Guest: hồng-đỏ (rose) — giao diện mua sắm thân thiện
  /// - Staff / Manager / Admin / Shipper: xanh navy/indigo — giao diện nghiệp vụ chuyên nghiệp
  ThemeData _themeFor(AppState state) {
    final isStaff = state.session != null && !state.isCustomer;
    if (isStaff) {
      // Admin / Staff / Manager / Shipper — Indigo theme
      return ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.nunitoTextTheme(ThemeData().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3730A3),
          primary: const Color(0xFF3730A3),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: const Color(0xFF3730A3).withValues(alpha: 0.15),
        ),
      );
    }
    // Customer / Guest — Rose theme
    return ThemeData(
      useMaterial3: true,
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData().textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE11D48),
        primary: const Color(0xFFE11D48),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => MaterialApp(
        title: 'ToyStore',
        debugShowCheckedModeBanner: false,
        theme: _themeFor(widget.state),
        home: FutureBuilder<void>(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SplashScreen();
            }
            return widget.state.session == null
                ? LoginScreen(state: widget.state)
                : AppShell(state: widget.state);
          },
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE11D48), Color(0xFFFB7185)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.toys_rounded,
                size: 80,
                color: Color(0xFFE11D48),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ToyStore',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
