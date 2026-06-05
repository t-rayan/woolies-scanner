import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/planogram_model.dart';
import '../../core/services/env_loader.dart';
import '../../core/services/planogram_parser.dart';

/// Provider for the API key from env_secrets.txt
final anthropicApiKeyProvider = FutureProvider<String?>((ref) async {
  return EnvLoader.get('ANTHROPIC_API_KEY');
});

/// Provider for the PlanogramParser service
final planogramParserProvider = FutureProvider<PlanogramParser?>((ref) async {
  final apiKeyAsync = await ref.watch(anthropicApiKeyProvider.future);
  if (apiKeyAsync == null || apiKeyAsync.trim().isEmpty) return null;
  return PlanogramParser(apiKeyAsync);
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

    final parser = await _ref.read(planogramParserProvider.future);
    if (parser == null) {
      state = AsyncValue.error(
        Exception('ANTHROPIC_API_KEY is not set. Check env_secrets.txt'),
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
