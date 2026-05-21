import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/fge_model.dart';
import 'planogram_parser.dart'; // Reuse ApiException

/// Specialized parser for FGE (Front Gondola End) sheets that handles
/// irregular layouts, "Sales Plan WC" date extraction, and ADDED/REMOVED flags.
class FgeParser {
  final String apiKey;

  static const String _model = 'claude-opus-4-7';
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  FgeParser(this.apiKey);

  /// Analyzes an FGE planogram sheet image and returns structured [FgePlanogram].
  Future<FgePlanogram> processFgeSheet(File imageFile) async {
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
        message: 'FGE Claude API Error: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final text = data['content'][0]['text'] as String;

    return _parseResponse(text);
  }

  /// Builds the detailed FGE-specific prompt for Claude.
  String _buildPrompt() {
    return '''You are analyzing a Woolworths FGE (Front Gondola End) "Weekly Sales Plan" sheet for nightfill workers.

CRITICAL — DATE EXTRACTION RULE:
Look at the VERY TOP HEADER of the sheet. Find the exact text "Sales Plan WC" or "Sales Plan W/C".
The date immediately following that text IS the planogram_date (e.g., "07/05/25").
Do NOT guess the date from any other numbers on the sheet. Only use the date after "Sales Plan WC".

SECTION IDENTIFICATION:
This sheet contains 15+ sections. Identify ALL of the following:
- "Front of Store Bin" (entrance display area)
- "ENT001" (entrance section)
- "FGE001" through "FGE012" (Front Gondola Ends)
Some sections may be labeled slightly differently (e.g., "FGE 007" instead of "FGE007") — normalize them.

LAYOUT DETECTION — This is critical:
For EACH section, determine the layout_type:

1. "standard_shelved" — Regular horizontal shelves (rows). Count the horizontal dividers.
   Most FGE boxes (FGE001-FGE006, FGE008-FGE012) are this type.
   Each shelf goes top-to-bottom: level 1 = top shelf, level 2 = next, etc.

2. "vertical_bulk" — Single full-height column, NO horizontal shelves.
   Example: FGE007 "Bulk End" has a giant vertical block.
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
  "sheet_type": "Front Gondola Ends & Entrance Display",
  "sections": [
    {
      "id": "FGE007",
      "layout_type": "vertical_bulk",
      "header": "HEADER - 40% OFF",
      "notes": "BULK END ONLY - shelves to be removed",
      "items": [
        {"name": "Product Name", "ref": "123456", "position": "top", "status": "normal"},
        {"name": "Another Product", "ref": "789012", "position": "bottom", "status": "added"}
      ]
    },
    {
      "id": "FGE003",
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

  /// Parses the JSON response into an [FgePlanogram] object.
  FgePlanogram _parseResponse(String text) {
    try {
      final startIndex = text.indexOf('{');
      final endIndex = text.lastIndexOf('}');

      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
        throw const FormatException('No valid JSON object found in FGE response');
      }

      final jsonStr = text.substring(startIndex, endIndex + 1);
      final Map<String, dynamic> parsed = jsonDecode(jsonStr);

      if (!parsed.containsKey('sections') || parsed['sections'] is! List) {
        throw const FormatException(
            'FGE response missing "sections" array');
      }

      final fgePlanogram = FgePlanogram.fromMap(parsed);

      // Sort sections: Front of Store Bin first, then ENT001, then FGE001-FGE012
      final sorted = List<FgeSection>.from(fgePlanogram.sections)
        ..sort((a, b) => _sortSections(a.id, b.id));

      return FgePlanogram(
        planogramDate: fgePlanogram.planogramDate.isNotEmpty
            ? fgePlanogram.planogramDate
            : 'Unknown Date',
        sheetType: fgePlanogram.sheetType.isNotEmpty
            ? fgePlanogram.sheetType
            : 'Front Gondola Ends & Entrance Display',
        sections: sorted,
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      debugPrint('❌ FGE Parse Error: $e\nRaw: $text');
      throw const FormatException(
          'Could not parse FGE Claude response into planogram structure.');
    }
  }

  /// Sorts sections logically: special sections first, then FGE by number.
  int _sortSections(String idA, String idB) {
    int priority(String id) {
      final lower = id.toLowerCase();
      if (lower.contains('front') || lower.contains('bin')) return 0;
      if (lower.contains('ent')) return 1;
      if (lower.contains('fge')) return 2;
      return 99;
    }

    final pA = priority(idA);
    final pB = priority(idB);
    if (pA != pB) return pA.compareTo(pB);

    // Both are FGE, sort by numeric ID
    final numA = _extractNumericId(idA);
    final numB = _extractNumericId(idB);
    return numA.compareTo(numB);
  }

  int _extractNumericId(String id) {
    final match = RegExp(r'(\d+)').firstMatch(id);
    if (match != null) return int.tryParse(match.group(1)!) ?? 0;
    return 0;
  }
}
