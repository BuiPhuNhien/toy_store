import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_state.dart';
import 'ui/app_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ToyStoreApp(state: AppState(ApiClient())));
}

class ToyStoreApp extends StatefulWidget {
  const ToyStoreApp({required this.state, super.key});

  final AppState state;

  @override
  State<ToyStoreApp> createState() => _ToyStoreAppState();
}

class _ToyStoreAppState extends State<ToyStoreApp> {
  late final Future<void> _initialization = widget.state.initialize();

  @override
  void dispose() {
    widget.state.api.close();
    widget.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToyStore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE11D48),
          surface: const Color(0xFFFFFBFA),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFFBFA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFBFA),
          foregroundColor: Color(0xFF20212A),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFF1E8E6)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8DEDC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8DEDC)),
          ),
        ),
      ),
      home: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _StartupError(message: snapshot.error.toString());
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const _StartupScreen();
          }
          return AnimatedBuilder(
            animation: widget.state,
            builder: (context, _) => widget.state.session == null
                ? LoginScreen(state: widget.state)
                : AppShell(state: widget.state),
          );
        },
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.toys_rounded, size: 52, color: Color(0xFFE11D48)),
          SizedBox(height: 16),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Không thể khởi động ứng dụng.\n$message'),
      ),
    ),
  );
}
