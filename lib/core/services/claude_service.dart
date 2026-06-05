import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ClaudeService {
  final String apiKey;

  static const String primaryModel = 'claude-opus-4-7';
  static const int targetMaxPixels = 2576;

  /// Compile-time override: `--dart-define=CLAUDE_API_KEY=sk-ant-...`
  static const String _dartDefineKey = String.fromEnvironment('CLAUDE_API_KEY');

  ClaudeService(this.apiKey);

  // ─── Factory ────────────────────────────────────────────────

  /// Creates a [ClaudeService] by resolving the API key from:
  /// 1. `--dart-define=CLAUDE_API_KEY=...` (all platforms, required for web)
  /// 2. `CLAUDE_API_KEY` in `.env` (mobile dev fallback)
  ///
  /// Throws a clear error if neither source provides a key.
  factory ClaudeService.fromEnvironment() {
    // Priority 1: compile-time --dart-define
    if (_dartDefineKey.isNotEmpty) return ClaudeService(_dartDefineKey);

    // Priority 2: flutter_dotenv (works on mobile where .env is loaded)
    final dotenvKey = dotenv.env['CLAUDE_API_KEY'] ?? '';
    if (dotenvKey.isNotEmpty) return ClaudeService(dotenvKey);

    // No key found — log and throw
    debugPrint(
      'Configuration Error: CLAUDE_API_KEY is not set. '
      'Run the web build using --dart-define parameters.',
    );
    throw Exception(
      'Configuration Error: CLAUDE_API_KEY is not set. '
      'Run the web build using --dart-define parameters.',
    );
  }

  static Future<Uint8List> preprocessImage(XFile file) async {
    final Uint8List rawBytes = await file.readAsBytes();
    final img.Image? original = img.decodeImage(rawBytes);
    if (original == null) {
      throw Exception('Could not decode image for preprocessing.');
    }
    final img.Image upright = img.bakeOrientation(original);
    img.Image resized;
    if (upright.width >= upright.height) {
      resized = img.copyResize(upright, width: targetMaxPixels);
    } else {
      resized = img.copyResize(upright, height: targetMaxPixels);
    }
    final Uint8List jpegBytes = img.encodeJpg(resized, quality: 92);
    debugPrint(
      '📐 Image preprocessed: '
      '${upright.width}x${upright.height} → ${resized.width}x${resized.height}px, '
      '${(jpegBytes.length / 1024).toStringAsFixed(1)}KB',
    );
    return jpegBytes;
  }

  // ─── Public API ───────────────────────────────────────────────

  /// Accepts a photo [XFile], preprocesses it, sends to Claude, returns products.
  Future<List<Map<String, dynamic>>> analyzeImage(XFile imageFile) async {
    final Uint8List processedBytes = await preprocessImage(imageFile);
    return _sendToClaudeDirect(processedBytes);
  }

  // ─── Direct HTTP call to Claude API ─────────────────────────

  /// Sends preprocessed JPEG [imageBytes] to the Anthropic API and returns
  /// parsed product records. Isolated so it can be replaced by a backend
  /// proxy call (see [_sendToSupabaseEdgeFunction] below).
  Future<List<Map<String, dynamic>>> _sendToClaudeDirect(
      Uint8List imageBytes) async {
    final String base64Image = base64Encode(imageBytes);

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': primaryModel,
        'max_tokens': 8192,
        'thinking': {'type': 'adaptive'},
        'output_config': {'effort': 'xhigh'},
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image',
                'source': {
                  'type': 'base64',
                  'media_type': 'image/jpeg',
                  'data': base64Image,
                },
              },
              {
                'type': 'text',
                'text': _buildPrompt(),
              }
            ],
          }
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API Error: ${response.body}');
    }

    final data = jsonDecode(response.body);
    String responseText = '';
    final List<dynamic> content = data['content'] as List<dynamic>;
    for (final block in content) {
      if (block['type'] == 'text') {
        responseText = block['text'] as String;
        break;
      }
    }
    if (responseText.isEmpty) {
      throw Exception('AI response contained no text block.');
    }

    final String authoritativeDate = _extractWcDate(responseText);
    return _parseResponse(responseText, authoritativeDate);
  }

  // ─── Future Backend Proxy (placeholder) ─────────────────────

  /// When this app is deployed to production on Firebase Hosting, the API key
  /// will be exposed in the browser's public JS bundle. To avoid this,
  /// migrate the Vision request to a secure backend endpoint (e.g. a Supabase
  /// Edge Function, Cloud Function, or Firebase Function) that holds the key
  /// server-side.
  ///
  /// Uncomment and wire this method into [analyzeImage] once the backend is
  /// deployed. The backend endpoint should accept the same preprocessed JPEG
  /// bytes and return the same JSON structure as [_sendToClaudeDirect].
  ///
  // Future<List<Map<String, dynamic>>> _sendToSupabaseEdgeFunction(
  //     Uint8List imageBytes) async {
  //   final String base64Image = base64Encode(imageBytes);
  //
  //   // TODO: Replace with your actual Edge Function URL
  //   final response = await http.post(
  //     Uri.parse(
  //       'https://YOUR-PROJECT.supabase.co/functions/v1/analyze-planogram',
  //     ),
  //     headers: {
  //       'Content-Type': 'application/json',
  //       // The anon key is safe to expose; the Edge Function validates the
  //       // request and applies its own server-side CLAUDE_API_KEY.
  //       'Authorization': 'Bearer ${SupabaseService.instance.client.auth}' ,
  //     },
  //     body: jsonEncode({
  //       'image': base64Image,
  //       'model': primaryModel,
  //       'prompt': _buildPrompt(),
  //     }),
  //   );
  //
  //   if (response.statusCode != 200) {
  //     throw Exception('Edge Function Error: ${response.body}');
  //   }
  //
  //   final data = jsonDecode(response.body) as Map<String, dynamic>;
  //   final responseText = data['result'] as String;
  //   final String authoritativeDate = _extractWcDate(responseText);
  //   return _parseResponse(responseText, authoritativeDate);
  // }

  String _buildPrompt() {
    return '''
CRITICAL DATE RULE — Extract ONLY the date after "Sales Plan WC".
- Locate "Sales Plan WC" or "WC" at the very top of the page.
- Extract ONLY the date immediately after "WC" (e.g., "10/04/25").
- Use THIS SAME DATE for EVERY product.
- If you cannot find "WC", use today's date.

IMAGE CONTEXT:
- This image is a wide-format retail planogram sheet in Landscape orientation.
- The image has been pre-processed so the longest edge is exactly 2576 pixels.
- Use this 2576px coordinate space for all bounding box values.

LITERALISM RULE (CRITICAL):
- Be STRICTLY LITERAL when reading Ref / Article numbers.
- If a Ref number is smudge-distorted, partially hidden, or unreadable due to
  flash glare, output "[REDACTED]" or "?" — do NOT guess or hallucinate digits.
- Product names may be extracted as best-effort, but Ref numbers must be
  as accurate as possible.

LOW-QUALITY SCAN HANDLING:
This image may have: camera flash glare, paper texture, blurred/warped text.
1. Prioritize Ref numbers — they are the most critical data field.
2. Scan FGE boxes carefully for small text.
3. Ignore scan artifacts (paper fibers, staple shadows, contrast edges).

SHEET TYPE DETECTION:
Look at the page title/header. Is this a:
  (A) BACK GONDOLA ENDS sheet → OGE type (OGE001-OGE012 boxes only)
  (B) FRONT GONDOLA ENDS sheet → FGE type (top displays + FGE001-FGE015)

=== IF OGE (Back Gondola Ends) ===
Simple grid — no special-display row:
  [OGE001] [OGE002] [OGE003] ...through OGE012
Label each product with its exact box ID (e.g., "OGE001", "OGE005").

=== IF FGE (Front Gondola Ends) ===
Two-zone layout divided by a horizontal divider line:

ROW 1 (ABOVE divider — Special Displays):
  [Front of Store BIN] | [ENT - Entrance] | [POS - Flexi Stand]

--- HORIZONTAL DIVIDER (STRICT BARRIER) ---

ROW 2+ (BELOW divider — Numbered FGE Boxes):
  [FGE001] [FGE002] [FGE003] ...through FGE015

FGE SPATIAL RULES:
1. **No Sliding**: Only assign BIN/ENT/POS if that SPECIFIC header is above.
   NEVER pull from FGE001 to fill an empty BIN/ENT/POS.
2. **Divider Barrier**: Everything below the divider = FGE001-FGE015 ONLY.
3. **Missing Box**: If "BIN", "ENT", or "POS" keyword is absent → omit that aisle.
4. **Row Markers**: Append "-R1" (top row) or "-R2" (numbered boxes).

OUTPUT FORMAT — ULTRA-CONCISE JSON:
[{"n":"...","b":"...","a":"...","d":"...","x":0,"y":0,"w":0,"h":0}]

- n = product name (exact, or best-effort if distorted)
- b = Ref / Article number (highest priority — use [REDACTED] or ? if unsure)
- a = aisle with row marker (e.g., "FGE003-R2", "BIN-R1")
- d = date from "Sales Plan WC" ONLY (same for ALL products)
- x,y = top-left pixel coordinate of this product's Ref number box
- w,h = width and height of the Ref number bounding box in pixels
  (Coordinates at 2576px resolution. Omit if uncertain; use 0 for unknown.)

Return ONLY the JSON array. No explanation, no markdown.
''';
  }

  String _extractWcDate(String text) {
    final wcRegex = RegExp(
      r'WC[\s:]*(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
      caseSensitive: false,
    );
    final match = wcRegex.firstMatch(text);
    if (match != null) {
      final day = match.group(1)!.padLeft(2, '0');
      final month = match.group(2)!.padLeft(2, '0');
      var year = match.group(3)!;
      if (year.length == 2) year = '20$year';
      return '$day/$month/$year';
    }
    final planRegex = RegExp(
      r'(?:Sales\s+)?Plan\s+(?:WC\s+)?(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
      caseSensitive: false,
    );
    final planMatch = planRegex.firstMatch(text);
    if (planMatch != null) {
      return _normalizeDateStr(planMatch.group(1)!);
    }
    return '';
  }

  String _normalizeDateStr(String raw) {
    final clean = raw.replaceAll('-', '/');
    final parts = clean.split('/');
    if (parts.length != 3) return '';
    final day = parts[0].padLeft(2, '0');
    final month = parts[1].padLeft(2, '0');
    var year = parts[2];
    if (year.length == 2) year = '20$year';
    return '$day/$month/$year';
  }

  List<Map<String, dynamic>> _parseResponse(
      String text, String authoritativeDate) {
    try {
      var clean = text.trim();
      if (clean.startsWith('```')) {
        final firstNewline = clean.indexOf('\n');
        if (firstNewline != -1) {
          clean = clean.substring(firstNewline + 1);
        }
        final lastFence = clean.lastIndexOf('```');
        if (lastFence != -1) {
          clean = clean.substring(0, lastFence).trim();
        }
      }

      final startIndex = clean.indexOf('[');
      final endIndex = clean.lastIndexOf(']');
      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
        throw Exception(
          'AI response was incomplete. Please try again with a clearer photo.',
        );
      }

      final jsonStr = clean.substring(startIndex, endIndex + 1);
      List<dynamic> rawList = jsonDecode(jsonStr) as List<dynamic>;

      final topRowAisles = <String>{'BIN', 'ENT', 'POS'};
      final fgePattern = RegExp(r'^FGE\d{3}');
      final ogePattern = RegExp(r'^OGE\d{3}');

      List<Map<String, dynamic>> parsed = [];
      bool hasFgeNumbered = false;
      bool hasOgeNumbered = false;
      int topRowCount = 0;

      for (final item in rawList) {
        if (item == null || item is! Map) continue;

        final n = item['n']?.toString() ?? '';
        final b = item['b']?.toString() ?? '';
        var a = (item['a']?.toString() ?? '').toUpperCase().trim();
        var d = (item['d']?.toString() ?? '').trim();

        if (authoritativeDate.isNotEmpty) {
          d = authoritativeDate;
        } else {
          d = _normalizeDateStr(d);
          if (d.isEmpty) {
            d = DateTime.now().toString().substring(0, 10).replaceAll('-', '/');
          }
        }

        final cleanAisle = a.replaceAll(RegExp(r'-R[12]$'), '').trim();

        if (a.endsWith('-R2') ||
            fgePattern.hasMatch(cleanAisle) ||
            ogePattern.hasMatch(cleanAisle)) {
          if (fgePattern.hasMatch(cleanAisle)) hasFgeNumbered = true;
          if (ogePattern.hasMatch(cleanAisle)) hasOgeNumbered = true;
        }
        if (a.endsWith('-R1') || topRowAisles.contains(cleanAisle)) {
          topRowCount++;
        }

        String finalAisle = cleanAisle;
        if (finalAisle.startsWith('POS') ||
            finalAisle.contains('POSITION') ||
            finalAisle.contains('FLEXI')) {
          finalAisle = 'POS';
        } else if (finalAisle == 'BIN' ||
            finalAisle.startsWith('BIN') ||
            finalAisle.contains('FRONT OF STORE')) {
          finalAisle = 'BIN';
        }

        parsed.add({
          'name': n,
          'barcode': b,
          'aisle': finalAisle,
          'planogram_date': d,
          'bbox_x': (item['x'] as num?)?.toInt() ?? 0,
          'bbox_y': (item['y'] as num?)?.toInt() ?? 0,
          'bbox_w': (item['w'] as num?)?.toInt() ?? 0,
          'bbox_h': (item['h'] as num?)?.toInt() ?? 0,
        });
      }

      if (topRowCount > 0 && !hasFgeNumbered && !hasOgeNumbered) {
        for (final item in parsed) {
          if (topRowAisles.contains(item['aisle'] as String)) {
            item['aisle'] = 'FGE';
          }
        }
      }

      return parsed;
    } catch (e) {
      debugPrint('❌ Parsing Error: $e\nResponse (${text.length} chars): $text');
      throw Exception(
        'Could not process all items. Try scanning in two photos.',
      );
    }
  }
}
