import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('Error: .env file not found');
    return;
  }

  final lines = await envFile.readAsLines();
  String? apiKey;
  for (final line in lines) {
    if (line.startsWith('ANTHROPIC_API_KEY=')) {
      apiKey = line.split('=')[1].trim();
      break;
    }
  }

  if (apiKey == null) {
    print('Error: ANTHROPIC_API_KEY not found in .env');
    return;
  }

  print('Testing API with model: claude-3-haiku-20240307');
  
  final url = Uri.parse('https://api.anthropic.com/v1/messages');
  final body = {
    'model': 'claude-3-haiku-20240307',
    'max_tokens': 10,
    'messages': [
      {'role': 'user', 'content': 'Hi'}
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

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
