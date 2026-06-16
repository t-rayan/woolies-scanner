import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';
import '../features/cage/cage_provider.dart';

/// A shared cage FAB button with a live badge count.
/// Navigates to the cage screen.
class CageFabButton extends ConsumerWidget {
  const CageFabButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cageCount = ref.watch(cageProvider).length;

    return FloatingActionButton(
      heroTag: 'cage',
      onPressed: () => context.push('/cage'),
      backgroundColor: AppColors.black,
      elevation: 4,
      mini: true,
      child: Badge(
        label: Text('$cageCount'),
        isLabelVisible: cageCount > 0,
        backgroundColor: Colors.red.shade700,
        textColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle:
            const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
        child: const Icon(Icons.inventory_2_rounded,
            color: AppColors.white, size: 18),
      ),
    );
  }
}
