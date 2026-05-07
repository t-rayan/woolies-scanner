import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ClaudeService {
  final String _apiKey;
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _version = '2023-06-01'; 
  
  // Restoring STABLE model IDs to resolve 404 errors
  static const _primaryModel = 'claude-3-5-sonnet-20241022'; 
  static const _fallbackModel = 'claude-3-5-haiku-20241022';

  ClaudeService(this._apiKey);

  Future<List<Map<String, dynamic>>> analyzeImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final ext = imageFile.path.split('.').last.toLowerCase();
    final mediaType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    const systemPrompt = '''
Objective: HIGH-PRECISION extraction of Woolworths Planogram data (OGE or FGE).

CRITICAL RULES:
1. IDENTIFY SHEET TYPE: Look for titles like "BACK GONDOLA ENDS" (OGE) or "FRONT GONDOLA ENDS" (FGE).
2. DATE: Find the "Sales plan wc" or "WC" date at the very top (DD/MM/YY).
3. EXTRACTION:
   - For OGE: Scan columns OGE001-OGE012.
   - For FGE: Scan FGE columns.
   - Rows with split boxes (Left/Right) MUST be extracted as separate items.
4. TEXT: Return exact product names and exact Ref numbers.

OUTPUT FORMAT (JSON):
{
  "date": "DD/MM/YY",
  "sheet_type": "OGE" or "FGE",
  "data": {
    "COLUMN_ID": [
       ["Product Name", "Ref: Number"],
       ["Next Product", "Ref: Number"]
    ]
  }
}
Return RAW JSON only. Do not truncate.
''';

    try {
      String responseBody;
      try {
        debugPrint('🚀 [Parser] Extracting with $_primaryModel...');
        responseBody = await _executeRequest(
          model: _primaryModel,
          base64Image: base64Image,
          mediaType: mediaType,
          prompt: systemPrompt,
          maxTokens: 8192, 
        );
      } catch (e) {
        debugPrint('⚠️ Falling back to $_fallbackModel...');
        responseBody = await _executeRequest(
          model: _fallbackModel,
          base64Image: base64Image,
          mediaType: mediaType,
          prompt: systemPrompt,
          maxTokens: 4096,
        );
      }

      final decoded = jsonDecode(_stripMarkdownCodeFences(responseBody));
      final dateStr = decoded['date']?.toString() ?? 'Unknown';
      final sheetType = decoded['sheet_type']?.toString().toUpperCase() ?? 'OGE';
      final dataMap = decoded['data'] as Map<String, dynamic>? ?? {};

      final List<Map<String, dynamic>> finalProducts = [];
      
      dataMap.forEach((aisleId, cells) {
        if (cells is List) {
          for (var cell in cells) {
            if (cell is List && cell.length >= 2) {
              finalProducts.add({
                'name': cell[0].toString().trim(),
                'barcode': cell[1].toString().trim(),
                'aisle': aisleId,
                'planogramDate': dateStr,
                'sheetName': sheetType,
                'category': 'General',
                'estimatedPrice': 0.0,
              });
            }
          }
        }
      });

      debugPrint('✅ Processed ${finalProducts.length} items from $sheetType sheet.');
      return finalProducts;
    } catch (e) {
      debugPrint('❌ OCR Error: $e');
      rethrow;
    }
  }

  Future<String> _executeRequest({
    required String model,
    required String base64Image,
    required String mediaType,
    required String prompt,
    required int maxTokens,
  }) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'x-api-key': _apiKey.trim(),
        'anthropic-version': _version,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image', 
                'source': {'type': 'base64', 'media_type': mediaType, 'data': base64Image}
              },
              {'type': 'text', 'text': prompt}
            ],
          }
        ],
      }),
    ).timeout(const Duration(seconds: 240));

    if (response.statusCode != 200) {
      throw Exception('Claude API Error: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List;
    return content.map((c) => c['text']).join('\n');
  }

  String _stripMarkdownCodeFences(String content) {
    var cleaned = content.trim();
    if (cleaned.startsWith('```json')) cleaned = cleaned.substring(7).trimLeft();
    else if (cleaned.startsWith('```')) cleaned = cleaned.substring(3).trimLeft();
    if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3).trimRight();
    return cleaned;
  }

  void dispose() {
    debugPrint('ClaudeService disposed.');
  }
}