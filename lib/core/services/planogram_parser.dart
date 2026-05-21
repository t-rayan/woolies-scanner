import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/planogram_model.dart';

/// Service that uses Claude Opus 4.7 Vision API to parse Woolworths
/// Weekly Sales Plan (Planogram) sheets into structured data.
class PlanogramParser {
  final String apiKey;

  static const String _model = 'claude-opus-4-7';
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  PlanogramParser(this.apiKey);

  /// Analyzes a planogram sheet image and returns structured [Planogram] data.
  Future<Planogram> processPlanogram(File imageFile) async {
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

CRITICAL CONTEXT:
- This sheet contains 12 boxes labeled OGE001 through OGE012 (Back Gondola Ends).
- Each box = one gondola end (aisle end) in the store.
- Within each box, vertical rows = physical shelves (top to bottom).
- If a row is split into two+ columns, multiple product groups share that shelf.
- Each product has a NAME and a REF NUMBER (numeric code).
- IGNORE any text that says "refer to visual" — these are not products.

YOUR TASK:
Extract ALL product data following this EXACT spatial hierarchy:

1. Identify all 12 boxes (OGE001-OGE012)
2. For each box, determine the PROMOTION TYPE (e.g., "1/2 PRICE", "WEEKLY SPECIAL", etc.)
3. Parse each shelf TOP TO BOTTOM (shelf 1 = top shelf)
4. If a shelf has multiple columns/sections, list ALL products in their correct groups
5. Capture EVERY product name and EVERY ref number

OUTPUT FORMAT — Return ONLY valid JSON with this exact structure:
{
  "planogram_date": "DD/MM/YY",
  "category": "Back Gondola Ends",
  "aisles": [
    {
      "id": "OGE001",
      "promo_type": "1/2 PRICE",
      "shelves": [
        {
          "level": 1,
          "products": [
            {"name": "Product Name Here", "ref": ["123456", "789012"]},
            {"name": "Second Product Group", "ref": ["345678"]}
          ]
        }
      ]
    }
  ]
}

IMPORTANT RULES:
- Return ONLY the JSON object. No markdown, no explanations.
- If a shelf has no products, include it with an empty products array.
- If a shelf is split (two columns), include multiple product entries for that level.
- Include ALL ref numbers found — they are critical for picking.
- Double check you haven't missed any products across all 12 boxes.
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
        planogramDate: planogram.planogramDate,
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
