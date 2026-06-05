import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Standalone .env file loader that works on ALL platforms (web, Android, iOS)
/// by reading from the asset bundle via [rootBundle].
///
/// No dependency on flutter_dotenv.
class EnvLoader {
  static final Map<String, String> _env = {};
  static bool _loaded = false;

  /// Call once at app startup.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('.env');
      for (final line in raw.split('\n')) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('#')) continue;
        final idx = t.indexOf('=');
        if (idx == -1) continue;
        final k = t.substring(0, idx).trim();
        final v = t.substring(idx + 1).trim();
        _env[k] = v;
      }
      _loaded = true;
      debugPrint('[ENV] Loaded ${_env.length} variables from .env');
    } catch (e) {
      debugPrint('[ENV] Failed to load .env: $e');
    }
  }

  /// Returns the value for [key], or [defaultValue] if not found.
  static String? get(String key, {String? defaultValue}) {
    return _env[key] ?? defaultValue;
  }

  /// Returns true if the loader has finished reading the file.
  static bool get isLoaded => _loaded;

  /// Returns the entire env map (for debugging).
  static Map<String, String> get all => Map.unmodifiable(_env);
}
