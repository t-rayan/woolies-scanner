import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/home/home_screen.dart';
import 'features/products/product_list_screen.dart';
import 'features/scanner/scanner_screen.dart';
import 'core/constants/app_colors.dart';
import 'core/services/env_loader.dart';
import 'core/services/supabase_service.dart';

/// Logs a message to the browser console so you can see it live in devtools.
void _consoleLog(Object? message) {
  // ignore: avoid_print
  print('[WOOLIES] $message');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // Read Supabase credentials from two possible sources:
  //   1. Compile-time --dart-define (used by Firebase CI builds + local web)
  //   2. .env file via dotenv (used for local Android/iOS development)
  // ============================================================

  // 1st priority: --dart-define compile-time constant
  const dartDefineUrl = String.fromEnvironment('SUPABASE_URL');
  const dartDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // 2nd priority: env_secrets.txt from asset bundle
  // (load may fail on web before runApp; get() retries lazily)
  await EnvLoader.load();
  final envUrl = await EnvLoader.get('SUPABASE_URL');
  final envKey = await EnvLoader.get('SUPABASE_ANON_KEY');

  // Pick whichever is available
  final supabaseUrl = dartDefineUrl.isNotEmpty ? dartDefineUrl : (envUrl ?? '');
  final supabaseAnonKey =
      dartDefineKey.isNotEmpty ? dartDefineKey : (envKey ?? '');

  _consoleLog('--- Supabase ---');
  _consoleLog(supabaseUrl.isEmpty ? '❌ URL: EMPTY' : '✅ URL: $supabaseUrl');
  _consoleLog(supabaseAnonKey.isEmpty
      ? '❌ KEY: EMPTY'
      : '✅ KEY: ${supabaseAnonKey.substring(0, 20)}...');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    _consoleLog('❌ Supabase unavailable');
  } else {
    try {
      await SupabaseService.instance.initialize(
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
      );
      _consoleLog('✅ Supabase initialized');
    } catch (e) {
      _consoleLog('❌ Supabase init failed: $e');
    }
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
