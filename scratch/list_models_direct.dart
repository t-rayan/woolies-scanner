import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  String? apiKey;
  for (final line in lines) {
    if (line.startsWith('ANTHROPIC_API_KEY=')) {
      apiKey = line.split('=')[1].trim();
      break;
    }
  }

  if (apiKey == null) {
    print('Error: ANTHROPIC_API_KEY not found');
    return;
  }

  print('Listing available models from Anthropic...');
  
  final url = Uri.parse('https://api.anthropic.com/v1/models');

  try {
    final response = await http.get(
      url,
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
    );

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
