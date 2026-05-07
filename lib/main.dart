import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/products/product_list_screen.dart';
import 'features/scanner/scanner_screen.dart';
import 'core/constants/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(
    const ProviderScope(
      child: WooliesApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    if (state.uri.path == '/scanner') {
      final apiKey = dotenv.env['ANTHROPIC_API_KEY'];
      if (apiKey == null || apiKey.trim().isEmpty) {
        return '/error?code=missing_api_key';
      }
    }
    return null;
  },
  errorBuilder: (context, state) => RouterErrorScreen(
    message: 'Page not found for "${state.uri}".',
  ),
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: '/database',
      builder: (context, state) => ProductListScreen(
        date: state.uri.queryParameters['date'],
      ),
    ),
    GoRoute(
      path: '/error',
      builder: (context, state) => RouterErrorScreen(
        message: switch (state.uri.queryParameters['code']) {
          'missing_api_key' =>
            'Scanner is unavailable. ANTHROPIC_API_KEY is missing.',
          _ => 'Unable to open this page.',
        },
      ),
    ),
  ],
);

class WooliesApp extends StatelessWidget {
  const WooliesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Woolies Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.black,
          primary: AppColors.black,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

class RouterErrorScreen extends StatelessWidget {
  final String message;

  const RouterErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Navigation Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.black),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
