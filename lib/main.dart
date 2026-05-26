import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/products/product_list_screen.dart';
import 'features/scanner/scanner_screen.dart';
import 'core/constants/app_colors.dart';
import 'core/services/supabase_service.dart';

/// Logs a message to the browser console so you can see it live in devtools.
void _consoleLog(Object? message) {
  // ignore: avoid_print
  print('[WOOLIES] $message');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // Read Supabase credentials from compile-time --dart-define
  // (set in .github/workflows/firebase-hosting-merge.yml)
  // ============================================================
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  _consoleLog('--- Supabase Credentials Check ---');
  _consoleLog(
      'SUPABASE_URL  => "${supabaseUrl.isEmpty ? '(EMPTY!)' : supabaseUrl}"');
  _consoleLog(
      'SUPABASE_ANON_KEY => "${supabaseAnonKey.isEmpty ? '(EMPTY!)' : '${supabaseAnonKey.substring(0, 20)}...'}"');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    _consoleLog('❌ CRITICAL: One or both --dart-define variables are EMPTY!');
    _consoleLog(
        '   Check that the GitHub Secret names match the --dart-define names.');

    // ════════════════════════════════════════════════
    // 🔥 MOST LIKELY CAUSE:
    //   The GitHub Action workflow file defines:
    //     --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}
    //   but the secret name in GitHub might be different, OR
    //   the values may contain special characters that need quoting.
    // ════════════════════════════════════════════════
  }

  // Initialize Supabase (pass credentials directly — no dotenv)
  try {
    await SupabaseService.instance.initialize(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  } catch (e) {
    _consoleLog('❌ Supabase initialize threw: $e');
    _consoleLog('   Stack trace:\n${StackTrace.current}');
  }

  runApp(
    ProviderScope(
      child: const WooliesApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // The scanner uses the Anthropic API key — no change needed here for now
    // since scanning is disabled on web (CORS). For local dev it still uses .env.
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
        sheet: state.uri.queryParameters['sheet'],
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
