import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  final apiKey = dotenv.env['ANTHROPIC_API_KEY']?.trim();
  
  if (apiKey == null) {
    print('❌ Error: ANTHROPIC_API_KEY not found in .env');
    return;
  }

  print('🚀 Testing Direct Anthropic API Call...');
  print('Model: claude-3-haiku-20240307');
  
  final url = Uri.parse('https://api.anthropic.com/v1/messages');
  
  final body = {
    'model': 'claude-3-haiku-20240307',
    'max_tokens': 1024,
    'messages': [
      {'role': 'user', 'content': 'Hello, identify yourself.'}
    ]
  };

  try {
    final response = await http.post(
      url,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );

    print('📡 Status Code: ${response.statusCode}');
    print('📦 Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      print('✅ SUCCESS! The API is reachable and working.');
    } else {
      print('❌ FAILED with status ${response.statusCode}');
    }
  } catch (e) {
    print('⚠️ Network Error: $e');
  }
}
