import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('🔍 Probing Anthropic Models (Zero-Dependency version)...');
  
  String? apiKey;
  try {
    final envFile = File('.env');
    if (await envFile.exists()) {
      final lines = await envFile.readAsLines();
      for (final line in lines) {
        if (line.startsWith('ANTHROPIC_API_KEY=')) {
          apiKey = line.split('=')[1].trim();
          // Remove potential quotes
          if ((apiKey.startsWith("'") && apiKey.endsWith("'")) ||
              (apiKey.startsWith('"') && apiKey.endsWith('"'))) {
            apiKey = apiKey.substring(1, apiKey.length - 1);
          }
        }
      }
    }
  } catch (e) {
    print('⚠️ Error reading .env: $e');
  }

  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Error: ANTHROPIC_API_KEY not found in .env');
    return;
  }

  print('Key starts with: ${apiKey.substring(0, 8)}...');
  
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
      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        print('✅ SUCCESS: This model is available.');
      } else {
        print('❌ FAILED: ${decoded['error']?['message'] ?? response.body}');
      }
    } catch (e) {
      print('⚠️ Network Error: $e');
    }
  }
}
