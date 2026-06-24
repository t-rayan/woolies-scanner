import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/planogram_model.dart';

/// Service that uses Claude Opus 4.7 Vision API to parse Woolworths
/// Weekly Sales Plan (Planogram) sheets into structured data.
class PlanogramParser {
  final String apiKey;

  static const String _model = 'claude-opus-4-7';
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  PlanogramParser(this.apiKey);

  Future<Planogram> processPlanogram(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 8192,
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
              },
            ],
          }
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Claude API Error: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final text = data['content'][0]['text'] as String;

    return _parseResponse(text);
  }

  /// Builds the detailed prompt instructing Claude how to parse the sheet.
  String _buildPrompt() {
    return '''You are analyzing a Woolworths "Weekly Sales Plan" (Planogram) sheet for nightfill workers.

CRITICAL — DATE EXTRACTION RULE:
Look at the VERY TOP HEADER of the sheet. Find the exact text "Sales Plan WC" or "Sales Plan W/C".
The date immediately following that text IS the planogram_date.
Example format: if it says "WC 07/05/26", extract "07/05/26".
Do NOT guess the date from any other numbers on the sheet. Only use the date after "Sales Plan WC".
Note: We are currently in the year 2026, so expect the year to reflect 2026 ('26).

SECTION IDENTIFICATION:
This sheet contains 12 sections. Identify ALL of the following:
- "OGE001" through "OGE012" (Back Gondola Ends)
Some sections may be labeled slightly differently (e.g., "OGE 007" instead of "OGE007") — normalize them.

LAYOUT DETECTION — This is critical:
For EACH section, determine the layout_type:

1. "standard_shelved" — Regular horizontal shelves (rows). Count the horizontal dividers.
   Each shelf goes top-to-bottom: level 1 = top shelf, level 2 = next, etc.

2. "vertical_bulk" — Single full-height column, NO horizontal shelves.
   Example: OGE007 "Bulk End" has a giant vertical block.
   Items may be stacked vertically within this block (top items listed first).
   Use "position" field: "top", "middle", "bottom" to show vertical placement.

3. "side_stack" — Has "Side Stacks" or vertical columns alongside shelves.
   These have products arranged in vertical columns.
   Use "position": "left_stack", "right_stack", etc.

CONTENT EXTRACTION:
For each section, capture:
- Header Text (e.g., "HEADER - 1/2 PRICE", "HEADER - 40% OFF")
- Product Names
- Ref Numbers (these are 5-7 digit numeric codes)
- The header often tells you the promotion type

CRITICAL — "ADDED" / "REMOVED" FLAGS:
You will see small red or blue text labels next to some products saying "REMOVED" or "ADDED".
These are VERY IMPORTANT for Tuesday night setups.
- "REMOVED" = This product is being taken off the shelf this week
- "ADDED" = This product is being put on the shelf this week
Include these flags in the "status" field for each item.

OUTPUT FORMAT — Return ONLY valid JSON with this exact adaptive structure:
{
  "planogram_date": "07/05/25",
  "sheet_type": "Back Gondola Ends",
  "sections": [
    {
      "id": "OGE007",
      "layout_type": "vertical_bulk",
      "header": "HEADER - 40% OFF",
      "notes": "BULK END ONLY - shelves to be removed",
      "items": [
        {"name": "Product Name", "ref": "123456", "position": "top", "status": "normal"},
        {"name": "Another Product", "ref": "789012", "position": "bottom", "status": "added"}
      ]
    },
    {
      "id": "OGE003",
      "layout_type": "standard_shelved",
      "header": "HEADER - 1/2 PRICE",
      "notes": "",
      "shelves": [
        {
          "level": 1,
          "items": [
            {"name": "Product Name", "ref": "123456", "position": "default", "status": "normal"}
          ]
        },
        {
          "level": 2,
          "items": [
            {"name": "Product A", "ref": "789012", "position": "default", "status": "removed"},
            {"name": "Product B", "ref": "345678", "position": "default", "status": "added"}
          ]
        }
      ]
    }
  ]
}

IMPORTANT RULES:
- Return ONLY the JSON object. No markdown, no explanations.
- For "standard_shelved" type: use the "shelves" array with "level" numbers.
- For "vertical_bulk" and "side_stack" types: use the "items" array directly.
- Include ALL products across ALL 15+ sections. Do not truncate.
- status must be one of: "normal", "added", "removed"
- If a product has no flag, use "normal".
- Double-check every section has been captured.
''';
  }

  /// Parses the JSON response from Claude into a [Planogram] object.
  Planogram _parseResponse(String text) {
    try {
      // Extract JSON from the response (handle potential markdown wrapping)
      final startIndex = text.indexOf('{');
      final endIndex = text.lastIndexOf('}');

      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
        throw const FormatException('No valid JSON object found in response');
      }

      final jsonStr = text.substring(startIndex, endIndex + 1);
      final Map<String, dynamic> parsed = jsonDecode(jsonStr);

      // Validate essential structure
      if (!parsed.containsKey('aisles') || parsed['aisles'] is! List) {
        throw const FormatException(
            'Response missing "aisles" array — Claude may not have parsed the sheet correctly.');
      }

      final planogram = Planogram.fromMap(parsed);

      // Sort aisles by their numeric ID (OGE001, OGE002, ..., OGE012)
      final sorted = List<PlanogramAisle>.from(planogram.aisles)
        ..sort((a, b) =>
            _extractNumericId(a.id).compareTo(_extractNumericId(b.id)));

      return Planogram(
        planogramDate: planogram.planogramDate.isNotEmpty
            ? planogram.planogramDate
            : 'Unknown Date',
        category: planogram.category.isNotEmpty
            ? planogram.category
            : 'Back Gondola Ends',
        aisles: sorted,
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Planogram Parse Error: $e\nRaw: $text');
      throw const FormatException(
          'Could not parse Claude response into planogram structure.');
    }
  }

  /// Extracts the numeric portion from an aisle ID (e.g., "OGE005" -> 5).
  int _extractNumericId(String id) {
    final match = RegExp(r'(\d+)').firstMatch(id);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }
}

/// Custom exception for API errors with status code details.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
