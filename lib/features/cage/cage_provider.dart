import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/product_model.dart';

class CageNotifier extends StateNotifier<List<Product>> {
  static const _storageKey = 'bne_pulse_cage_items';

  CageNotifier() : super([]) {
    _loadCageFromStorage(); // 🔄 Load items immediately on startup
  }

  // 📥 Load list from local browser memory
  Future<void> _loadCageFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_storageKey);

      if (savedJson != null) {
        final List<dynamic> decodedList = jsonDecode(savedJson);
        state = decodedList.map((item) => Product.fromJson(item)).toList();
      }
    } catch (e) {
      // Gracefully catch any loading errors
      state = [];
    }
  }

  // 💾 Save list to local browser memory
  Future<void> _saveCageToStorage(List<Product> newList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedJson =
          jsonEncode(newList.map((item) => item.toJson()).toList());
      await prefs.setString(_storageKey, encodedJson);
    } catch (e) {
      // Handle background write errors if necessary
    }
  }

  // ➕ Add item and persist
  void addToCage(Product product) {
    if (!state.any((item) =>
        item.barcode == product.barcode && item.name == product.name)) {
      final updatedList = [...state, product];
      state = updatedList;
      _saveCageToStorage(updatedList);
    }
  }

  // ➖ Remove item and persist
  void removeFromCage(Product product) {
    final updatedList = state.where((item) => item != product).toList();
    state = updatedList;
    _saveCageToStorage(updatedList);
  }

  // 🧹 Clear everything from state and memory
  void clearCage() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

// Global provider definition remains unchanged
final cageProvider = StateNotifierProvider<CageNotifier, List<Product>>((ref) {
  return CageNotifier();
});
