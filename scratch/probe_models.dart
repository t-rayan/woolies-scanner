import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  final apiKey = dotenv.env['ANTHROPIC_API_KEY']?.trim();
  
  if (apiKey == null) {
    print('❌ Error: ANTHROPIC_API_KEY not found');
    return;
  }

  print('🔍 Probing Anthropic Models...');
  
  // Note: Anthropic doesn't have a public "list models" endpoint like OpenAI,
  // but we can test a simple message with different model IDs to see what works.
  
  final modelsToTest = [
    'claude-3-5-sonnet-20241022',
    'claude-3-5-sonnet-20240620',
    'claude-3-haiku-20240307',
    'claude-3-opus-20240229',
  ];

  for (final model in modelsToTest) {
    print('\n-------------------');
    print('Testing Model: $model');
    
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'hi'}
          ]
        }),
      );

      print('Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ SUCCESS: This model is available.');
      } else {
        final error = jsonDecode(response.body);
        print('❌ FAILED: ${error['error']['message']}');
      }
    } catch (e) {
      print('⚠️ Error: $e');
    }
  }
}
