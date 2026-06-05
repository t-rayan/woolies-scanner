import 'package:flutter/services.dart';

/// Loads env vars from the asset bundle using [rootBundle].
///
/// On web, assets aren't available before [runApp], so the eager [load] call
/// in [main] may fail. The [get] method retries lazily on first access.
class EnvLoader {
  static final Map<String, String> _env = {};
  static bool _loaded = false;
  static bool _loadingAttempted = false;

  // Compile-time overrides from --dart-define (set in CI/CD)
  static const String _dartDefineSupabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String _dartDefineSupabaseKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _dartDefineAnthropicKey =
      String.fromEnvironment('ANTHROPIC_API_KEY');

  /// Attempts to load and parse env_secrets.txt.
  /// Safe to call multiple times — only tries once.
  static Future<void> load() async {
    if (_loadingAttempted) return;
    _loadingAttempted = true;
    try {
      final raw = await rootBundle.loadString('env_secrets.txt');
      for (final line in raw.split('\n')) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('#')) continue;
        final idx = t.indexOf('=');
        if (idx == -1) continue;
        _env[t.substring(0, idx).trim()] = t.substring(idx + 1).trim();
      }
      _loaded = true;
    } catch (_) {
      // First attempt failed (e.g. web before runApp). Reset so [get] retries.
      _loadingAttempted = false;
    }
  }

  /// Returns the value for [key]. Checks `--dart-define` first, then asset file.
  static Future<String?> get(String key) async {
    // 1st priority: compile-time --dart-define
    if (key == 'SUPABASE_URL' && _dartDefineSupabaseUrl.isNotEmpty) {
      return _dartDefineSupabaseUrl;
    }
    if (key == 'SUPABASE_ANON_KEY' && _dartDefineSupabaseKey.isNotEmpty) {
      return _dartDefineSupabaseKey;
    }
    if (key == 'ANTHROPIC_API_KEY' && _dartDefineAnthropicKey.isNotEmpty) {
      return _dartDefineAnthropicKey;
    }

    // 2nd priority: from asset file (retries if previous attempt failed)
    if (!_loaded) await load();
    return _env[key];
  }

  static bool get isLoaded => _loaded;
}
