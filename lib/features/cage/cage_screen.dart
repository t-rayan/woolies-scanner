import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import 'cage_provider.dart';

class CageScreen extends ConsumerWidget {
  const CageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 📦 Listen to your cage list state live
    final cageItems = ref.watch(cageProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'CAGE PICKING LIST',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.black),
        actions: [
          if (cageItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              tooltip: 'Clear Cage',
              onPressed: () {
                ref.read(cageProvider.notifier).clearCage();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CAGE CLEARED')),
                );
              },
            ),
        ],
      ),
      body: cageItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 64, color: AppColors.grey.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'YOUR CAGE IS EMPTY',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add products from your search results.',
                    style: TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: cageItems.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.lightGrey, height: 20),
              itemBuilder: (context, index) {
                final product = cageItems[index];
                final displayAisle = product.aisle?.toUpperCase() ??
                    product.sheetName?.toUpperCase() ??
                    'GEN';
                final isEnt = displayAisle.startsWith('ENT');

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.lightGrey, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.black,
                              ),
                            ),
                            if (product.barcode != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Ref/Barcode: ${product.barcode}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Aisle Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isEnt ? AppColors.black : AppColors.darkGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          displayAisle,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Swipe/Remove item individual button
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            color: Colors.red, size: 22),
                        onPressed: () {
                          ref
                              .read(cageProvider.notifier)
                              .removeFromCage(product);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
