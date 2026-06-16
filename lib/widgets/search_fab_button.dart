import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';
import '../features/products/product_provider.dart';

/// A shared big search FAB button used across screens.
/// Navigates to the dedicated search screen and clears any stale query.
class SearchFabButton extends ConsumerWidget {
  const SearchFabButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      heroTag: 'search',
      onPressed: () {
        // Clear any stale search query before navigating
        ref.read(scanSearchQueryProvider.notifier).state = '';
        context.push('/search');
      },
      backgroundColor: AppColors.black,
      elevation: 4,
      child: const Icon(Icons.search_rounded, color: AppColors.white),
    );
  }
}
