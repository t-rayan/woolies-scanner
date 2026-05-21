import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class ClaudeService {
  final String apiKey;

  static const String primaryModel = 'claude-opus-4-7';

  /// Target longest-edge resolution for 1:1 pixel mapping with Claude 4.7 Opus.
  static const int targetMaxPixels = 2576;

  ClaudeService(this.apiKey);

  /// Pre-processes an image for Claude:
  ///   1. Strips/rotates EXIF orientation so image is upright.
  ///   2. Resizes so the longest edge = [targetMaxPixels] (2576px).
  ///   3. Returns the raw JPEG bytes ready for base64 encoding.
  static Future<Uint8List> preprocessImage(File file) async {
    final Uint8List rawBytes = await file.readAsBytes();

    // Decode image (reads EXIF orientation automatically)
    final img.Image? original = img.decodeImage(rawBytes);
    if (original == null) {
      throw Exception('Could not decode image for preprocessing.');
    }

    // Step 1: Apply EXIF rotation so the image is upright
    final img.Image upright = img.bakeOrientation(original);

    // Step 2: Resize to 2576px on the longest edge, preserving aspect ratio
    img.Image resized;
    if (upright.width >= upright.height) {
      // Landscape: constrain width
      resized = img.copyResize(upright, width: targetMaxPixels);
    } else {
      // Portrait: constrain height
      resized = img.copyResize(upright, height: targetMaxPixels);
    }

    // Step 3: Encode back to JPEG (quality 92 — sweet spot for size/fidelity)
    final Uint8List jpegBytes = img.encodeJpg(resized, quality: 92);

    debugPrint('📐 Image preprocessed: '
        '${upright.width}x${upright.height} → ${resized.width}x${resized.height}px, '
        '${(jpegBytes.length / 1024).toStringAsFixed(1)}KB');

    return jpegBytes;
  }

  /// Sends the image to Claude and returns parsed product data.
  Future<List<Map<String, dynamic>>> analyzeImage(File imageFile) async {
    // Pre-process: EXIF-correct and resize
    final Uint8List processedBytes = await preprocessImage(imageFile);
    final String base64Image = base64Encode(processedBytes);

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

    // Find the text block (response may have thinking blocks interleaved)
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

    // Step 1: Extract the authoritative Sales Plan WC date
    final String authoritativeDate = _extractWcDate(responseText);

    // Step 2: Parse products and apply spatial barrier validation
    return _parseResponse(responseText, authoritativeDate);
  }

  /// Builds the extraction prompt with landscape / literalism / bounding-box
  /// instructions for Claude 4.7 Opus.
  String _buildPrompt() {
    return '''
CRITICAL DATE RULE — Extract ONLY the date after "Sales Plan WC".
- Locate "Sales Plan WC" or "WC" at the very top of the page.
- Extract ONLY the date immediately after "WC" (e.g., "10/04/25").
- Use THIS SAME DATE for EVERY product. Do NOT use any other date.
- If you cannot find "WC", use today's date.

IMAGE CONTEXT:
- This image is a wide-format retail planogram sheet in Landscape orientation.
- The image has been pre-processed so the longest edge is exactly 2576 pixels.
- Use this 2576px coordinate space for all bounding box values.

LITERALISM RULE (CRITICAL):
- Be STRICTLY LITERAL when reading Ref / Article numbers.
- If a Ref number is smudge-distorted, partially hidden, or unreadable due to
  flash glare, output "[REDACTED]" or "?" — do NOT guess or hallucinate digits.
- It is better to mark a Ref as unclear than to output a wrong number.
- Product names may be extracted as best-effort, but Ref numbers must be
  as accurate as possible. When in doubt, use surrounding context (product name,
  position in sequence) to verify digits.

LOW-QUALITY SCAN HANDLING:
This image may have: camera flash glare, paper texture, blurred/warped text.
1. Prioritize Ref numbers — they are the most critical data field.
2. Scan FGE boxes carefully for small text. Some boxes hold TWO products (Left/Right).
3. Ignore scan artifacts (paper fibers, staple shadows, contrast edges).

SHEET TYPE DETECTION:
Look at the page title/header. Is this a:
  (A) BACK GONDOLA ENDS sheet → OGE type (OGE001-OGE012 boxes only)
  (B) FRONT GONDOLA ENDS sheet → FGE type (top displays + FGE001-FGE015)

=== IF OGE (Back Gondola Ends) ===
Simple grid — no special-display row:
  [OGE001] [OGE002] [OGE003]
  ...through OGE012...
Label each product with its exact box ID (e.g., "OGE001", "OGE005").

=== IF FGE (Front Gondola Ends) ===
Two-zone layout divided by a horizontal divider line:

ROW 1 (ABOVE divider — Special Displays):
  [Front of Store BIN] | [ENT - Entrance] | [POS - Flexi Stand]

--- HORIZONTAL DIVIDER (STRICT BARRIER) ---

ROW 2+ (BELOW divider — Numbered FGE Boxes):
  [FGE001] [FGE002] [FGE003]
  [FGE004] [FGE005] [FGE006] ...through FGE015

FGE SPATIAL RULES:
1. **No Sliding**: Only assign BIN/ENT/POS if that SPECIFIC header is above.
   If BIN header has zero products → output nothing for BIN.
   NEVER pull from FGE001 to fill an empty BIN/ENT/POS.
2. **Divider Barrier**: Everything below the divider = FGE001-FGE015 ONLY.
   Nothing below the divider can be BIN/ENT/POS.
3. **Missing Box**: If "BIN", "ENT", or "POS" keyword is absent → omit that aisle.
4. **Row Markers**: Append "-R1" (top row) or "-R2" (numbered boxes).
   Examples: "OGE005-R2", "FGE003-R2", "BIN-R1", "POS-R1"

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

  /// Extracts the authoritative "Sales Plan WC" date.
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

  /// Parses the JSON output and applies spatial barrier validation.
  List<Map<String, dynamic>> _parseResponse(
      String text, String authoritativeDate) {
    try {
      // Step 1: Strip markdown code fences if present (```json [...] ```)
      var clean = text.trim();
      if (clean.startsWith('```')) {
        // Remove opening fence (```json or ```)
        final firstNewline = clean.indexOf('\n');
        if (firstNewline != -1) {
          clean = clean.substring(firstNewline + 1);
        }
        // Remove closing fence
        final lastFence = clean.lastIndexOf('```');
        if (lastFence != -1) {
          clean = clean.substring(0, lastFence).trim();
        }
      }

      final startIndex = clean.indexOf('[');
      final endIndex = clean.lastIndexOf(']');
      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
        debugPrint(
            '❌ No JSON array found in response. Full text (${text.length} chars):\n$text');
        throw Exception(
          'AI response was incomplete. Please try again with a clearer photo.',
        );
      }

      final jsonStr = clean.substring(startIndex, endIndex + 1);

      List<dynamic> rawList;
      try {
        rawList = jsonDecode(jsonStr) as List<dynamic>;
      } catch (jsonError) {
        debugPrint('❌ JSON parse failed: $jsonError');
        debugPrint('   Extracted JSON (${jsonStr.length} chars): $jsonStr');
        throw Exception(
          'Could not process all items. Try scanning in two photos.',
        );
      }

      final topRowAisles = <String>{'BIN', 'ENT', 'POS'};
      final fgeNumberedPattern = RegExp(r'^FGE\d{3}');
      final ogeNumberedPattern = RegExp(r'^OGE\d{3}');

      List<Map<String, dynamic>> parsed = [];
      bool hasFgeNumberedBoxes = false;
      bool hasOgeNumberedBoxes = false;
      int topRowProductCount = 0;

      for (final item in rawList) {
        // Skip null items or non-map items
        if (item == null || item is! Map) continue;

        final n = item['n']?.toString() ?? '';
        final b = item['b']?.toString() ?? '';
        var a = (item['a']?.toString() ?? '').toUpperCase().trim();
        var d = (item['d']?.toString() ?? '').trim();

        // Extract bounding box if provided
        final int bx = (item['x'] as num?)?.toInt() ?? 0;
        final int by = (item['y'] as num?)?.toInt() ?? 0;
        final int bw = (item['w'] as num?)?.toInt() ?? 0;
        final int bh = (item['h'] as num?)?.toInt() ?? 0;

        // ---- OVERRIDE DATE ----
        if (authoritativeDate.isNotEmpty) {
          d = authoritativeDate;
        } else {
          d = _normalizeDateStr(d);
          if (d.isEmpty) {
            d = DateTime.now().toString().substring(0, 10).replaceAll('-', '/');
          }
        }

        // ---- STRIP ROW MARKERS ----
        final cleanAisle = a.replaceAll(RegExp(r'-R[12]$'), '').trim();

        if (a.endsWith('-R2') ||
            fgeNumberedPattern.hasMatch(cleanAisle) ||
            ogeNumberedPattern.hasMatch(cleanAisle)) {
          if (fgeNumberedPattern.hasMatch(cleanAisle)) {
            hasFgeNumberedBoxes = true;
          }
          if (ogeNumberedPattern.hasMatch(cleanAisle)) {
            hasOgeNumberedBoxes = true;
          }
        }
        if (a.endsWith('-R1') || topRowAisles.contains(cleanAisle)) {
          topRowProductCount++;
        }

        // ---- NORMALIZE AISLE ----
        String finalAisle = cleanAisle;

        if (finalAisle.startsWith('POS') ||
            finalAisle.contains('POSITION') ||
            finalAisle.contains('FLEXI')) {
          finalAisle = 'POS';
        } else if (finalAisle == 'BIN' ||
            finalAisle.startsWith('BIN') ||
            finalAisle.contains('FRONT OF STORE')) {
          finalAisle = 'BIN';
        } else if (fgeNumberedPattern.hasMatch(finalAisle)) {
          hasFgeNumberedBoxes = true;
        } else if (ogeNumberedPattern.hasMatch(finalAisle)) {
          hasOgeNumberedBoxes = true;
        }

        parsed.add({
          'name': n,
          'barcode': b,
          'aisle': finalAisle,
          'planogram_date': d,
          'bbox_x': bx,
          'bbox_y': by,
          'bbox_w': bw,
          'bbox_h': bh,
        });
      }

      // ---- POST-PROCESSING: SLIDING DETECTION ----
      if (topRowProductCount > 0 &&
          !hasFgeNumberedBoxes &&
          !hasOgeNumberedBoxes) {
        debugPrint('⚠️ Spatial barrier violation detected: '
            'No FGE/OGE numbered boxes, but $topRowProductCount '
            'top-row products exist. Reclassifying as FGE.');
        for (final item in parsed) {
          if (topRowAisles.contains(item['aisle'] as String)) {
            item['aisle'] = 'FGE';
          }
        }
      }

      debugPrint('✅ Parsed ${parsed.length} products '
          '(OGE: $hasOgeNumberedBoxes, FGE: $hasFgeNumberedBoxes, '
          'top-row: $topRowProductCount)');

      return parsed;
    } catch (e) {
      debugPrint('❌ Parsing Error: $e\nResponse (${text.length} chars): $text');
      throw Exception(
        'Could not process all items. Try scanning in two photos.',
      );
    }
  }
}
