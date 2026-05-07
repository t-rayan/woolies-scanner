import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  final apiKey = dotenv.env['ANTHROPIC_API_KEY'];
  
  if (apiKey == null) {
    print('Error: ANTHROPIC_API_KEY not found in .env');
    return;
  }

  final client = AnthropicClient(
    config: AnthropicConfig(
      authProvider: ApiKeyProvider(apiKey),
    ),
  );

  try {
    print('Fetching available models...');
    final response = await client.models.list();
    print('Available Models:');
    for (final model in response.data) {
      print('- ${model.id}');
    }
  } catch (e) {
    print('Error fetching models: $e');
  } finally {
    client.close();
  }
}
