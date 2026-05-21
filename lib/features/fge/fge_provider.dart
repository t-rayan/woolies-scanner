import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/fge_model.dart';
import '../../core/services/fge_parser.dart';

/// Provider for the FGE parser service
final fgeParserProvider = Provider<FgeParser?>((ref) {
  final apiKey = dotenv.env['ANTHROPIC_API_KEY'];
  if (apiKey == null || apiKey.trim().isEmpty) return null;
  return FgeParser(apiKey);
});

/// Search query for the FGE global ref search
final fgeSearchQueryProvider = StateProvider<String>((ref) => '');

/// Async state for FGE planogram data
final fgePlanogramProvider =
    StateNotifierProvider<FgePlanogramNotifier, AsyncValue<FgePlanogram?>>(
        (ref) {
  return FgePlanogramNotifier(ref);
});

/// Filtered sections based on search query
final fgeFilteredSectionsProvider = Provider<List<FgeSection>>((ref) {
  final fgeAsync = ref.watch(fgePlanogramProvider);
  final query = ref.watch(fgeSearchQueryProvider);

  final planogram = fgeAsync.valueOrNull;
  if (planogram == null) return [];

  if (query.trim().isEmpty) return planogram.sections;

  // Search by ref number OR product name
  final results = <FgeSection>{};
  results.addAll(planogram.searchByRef(query));
  results.addAll(planogram.searchByName(query));

  // Return in original order
  return planogram.sections.where((s) => results.contains(s)).toList();
});

class FgePlanogramNotifier extends StateNotifier<AsyncValue<FgePlanogram?>> {
  final Ref _ref;

  FgePlanogramNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> processImage(XFile image) async {
    state = const AsyncValue.loading();

    final parser = _ref.read(fgeParserProvider);
    if (parser == null) {
      state = AsyncValue.error(
        Exception('ANTHROPIC_API_KEY is not set. Add it to your .env file.'),
        StackTrace.current,
      );
      return;
    }

    try {
      final planogram = await parser.processFgeSheet(image);
      state = AsyncValue.data(planogram);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Clear current data
  void clear() {
    state = const AsyncValue.data(null);
  }
}
