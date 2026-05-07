import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('🚀 Starting Pure Dart API Test...');
  
  String? apiKey;
  try {
    final envFile = File('.env');
    if (await envFile.exists()) {
      final content = await envFile.readAsString();
      final lines = content.split('\n');
      for (var line in lines) {
        if (line.trim().startsWith('ANTHROPIC_API_KEY=')) {
          apiKey = line.split('=')[1].trim();
          apiKey = apiKey.replaceAll("'", "").replaceAll('"', "");
        }
      }
    }
  } catch (e) {
    print('Error reading .env: $e');
  }

  if (apiKey == null) {
    print('❌ API Key not found');
    return;
  }

  print('Using Key: ${apiKey.substring(0, 8)}...');

  final models = ['claude-3-5-sonnet-20240620', 'claude-3-haiku-20240307'];
  
  for (var model in models) {
    print('\nTesting Model: $model');
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
      print('Body: ${response.body}');
    } catch (e) {
      print('Error: $e');
    }
  }
}
