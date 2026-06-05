import 'package:flutter/services.dart';

/// Loads env vars from the asset bundle using [rootBundle].
///
/// On web, assets aren't available before [runApp], so the eager [load] call
/// in [main] may fail. The [get] method retries lazily on first access.
class EnvLoader {
  static final Map<String, String> _env = {};
  static bool _loaded = false;
  static bool _loadingAttempted = false;

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

  /// Returns the value for [key]. Retries loading if previous attempt failed.
  static Future<String?> get(String key) async {
    if (!_loaded) await load();
    return _env[key];
  }

  static bool get isLoaded => _loaded;
}
