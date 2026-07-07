import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart'; // Needed for date formatting
import 'package:woolies_scanner/features/products/product_database_provider.dart';
import '../../../core/models/planogram_model.dart';
import '../../../core/models/product_model.dart'; // Import your Product model
import '../../../core/services/supabase_service.dart'; // Import your Supabase service

const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

final geminiPlanogramProvider =
    StateNotifierProvider<GeminiPlanogramNotifier, AsyncValue<Planogram?>>(
        (ref) {
  // Pass the supabase service to the notifier
  final supabase = ref.read(supabaseServiceProvider);
  return GeminiPlanogramNotifier(supabase);
});

class GeminiPlanogramNotifier extends StateNotifier<AsyncValue<Planogram?>> {
  final SupabaseService _supabase;
  GeminiPlanogramNotifier(this._supabase) : super(const AsyncValue.data(null));

  Future<void> scanSheet({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    if (_geminiKey.isEmpty) {
      state =
          AsyncValue.error('GEMINI_API_KEY is missing.', StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();

    // Define response outside to ensure it is available to the parsing logic
    GenerateContentResponse? response;

    try {
      final model =
          GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiKey);

      final structuredSchema = Schema.object(
        properties: {
          'planogram_date': Schema.string(),
          'category': Schema.string(),
          'aisles': Schema.array(
            items: Schema.object(
              properties: {
                'id': Schema.string(),
                'promo_type': Schema.string(),
                'shelves': Schema.array(
                  items: Schema.object(
                    properties: {
                      'level': Schema.integer(),
                      'products': Schema.array(
                        items: Schema.object(
                          properties: {
                            'name': Schema.string(),
                            'ref': Schema.array(items: Schema.string()),
                          },
                        ),
                      ),
                    },
                  ),
                ),
              },
            ),
          ),
        },
      );

      final content = [
        Content.multi([
          TextPart(
              'Analyze this planogram layout. Extract structured data matching the schema provided.'),
          DataPart(mimeType, imageBytes),
        ])
      ];

      response = await model.generateContent(
        content,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: structuredSchema,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return; // Exit if the API call fails
    }

    // Ensure response was populated and contains text
    if (response.text != null) {
      try {
        final Map<String, dynamic> decodedJson = jsonDecode(response.text!);
        final Planogram planogram = Planogram.fromMap(decodedJson);

        // Map Planogram to Product model
        final List<Product> productsToSave = [];
        final String today = DateFormat('dd/MM/yyyy').format(DateTime.now());

        for (var aisle in planogram.aisles) {
          for (var shelf in aisle.shelves) {
            for (var item in shelf.products) {
              productsToSave.add(Product(
                name: item.name,
                barcode: item.ref.isNotEmpty ? item.ref.first : null,
                aisle: aisle.id,
                planogramDate: planogram.planogramDate ?? today,
                sheetName: (aisle.id.startsWith('FGE') ||
                        aisle.id.startsWith('ENT') ||
                        aisle.id.startsWith('POS') ||
                        aisle.id.startsWith('BIN') ||
                        aisle.id.contains('FLEXI'))
                    ? 'FGE'
                    : 'OGE',
                scanDate: DateTime.now(),
              ));
            }
          }
        }

        // Save to Supabase
        await _supabase.insertProducts(productsToSave);

        state = AsyncValue.data(planogram);
      } catch (e, st) {
        state = AsyncValue.error('Failed to parse or save data: $e', st);
      }
    } else {
      state =
          AsyncValue.error('No data returned from Gemini.', StackTrace.current);
    }
  }
}
