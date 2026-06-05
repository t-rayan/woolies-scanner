import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/models/planogram_model.dart';
import '../../core/services/planogram_parser.dart';

/// Provider for the API key from .env
final anthropicApiKeyProvider = Provider<String?>((ref) {
  return dotenv.env['ANTHROPIC_API_KEY'];
});

/// Provider for the PlanogramParser service
final planogramParserProvider = Provider<PlanogramParser?>((ref) {
  final apiKey = ref.watch(anthropicApiKeyProvider);
  if (apiKey == null || apiKey.trim().isEmpty) return null;
  return PlanogramParser(apiKey);
});

/// Async state for the current planogram data
final planogramProvider =
    StateNotifierProvider<PlanogramNotifier, AsyncValue<Planogram?>>((ref) {
  return PlanogramNotifier(ref);
});

class PlanogramNotifier extends StateNotifier<AsyncValue<Planogram?>> {
  final Ref _ref;

  PlanogramNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Process a planogram sheet image
  Future<void> processImage(XFile image) async {
    state = const AsyncValue.loading();

    final parser = _ref.read(planogramParserProvider);
    if (parser == null) {
      state = AsyncValue.error(
        Exception('ANTHROPIC_API_KEY is not set. Add it to your .env file.'),
        StackTrace.current,
      );
      return;
    }

    try {
      final planogram = await parser.processPlanogram(image);
      state = AsyncValue.data(planogram);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Clear current planogram data
  void clear() {
    state = const AsyncValue.data(null);
  }
}
