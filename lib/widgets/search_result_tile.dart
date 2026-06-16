import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/models/product_model.dart';
import '../features/cage/cage_provider.dart';
import '../features/home/home_screen.dart';
import 'ref_chip.dart';

/// Ends that don't belong to this store — shown as disabled/grayed out.
const _disabledEnds = <String>{'FGE011', 'FGE012', 'OGE011', 'OGE012'};

/// Returns true if the aisle ID is a disabled end (not belonging to this store).
bool _isDisabledEnd(String aisle) =>
    _disabledEnds.contains(aisle.toUpperCase());

/// A search result tile with yellow-highlighted matching text,
/// prominent aisle badge, and an "ADD TO CAGE" button.
class SearchResultTile extends ConsumerWidget {
  final Product product;
  final String query;
  final String displayAisle;

  const SearchResultTile({
    super.key,
    required this.product,
    required this.query,
    required this.displayAisle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refs =
        product.barcode?.split(',').map((e) => e.trim()).toList() ?? [];
    final isOge = displayAisle.startsWith('OGE');
    final disabled = _isDisabledEnd(displayAisle);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: disabled ? AppColors.lightGrey : AppColors.white,
        border: Border.all(
          color: disabled
              ? AppColors.grey.withValues(alpha: 0.3)
              : AppColors.lightGrey,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HighlightedText(
                  text: product.name,
                  query: query.toUpperCase(),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: disabled ? AppColors.grey : AppColors.black),
                ),
                if (disabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'This end does not belong to this store',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (refs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: refs
                        .map((ref) => RefChip(ref: ref, query: query))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isOge ? Colors.teal.shade800 : Colors.blue.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(displayAisle,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
              if (!disabled) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    ref.read(cageProvider.notifier).addToCage(product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('${product.name.toUpperCase()} ADDED TO CAGE'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.grey.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_box_rounded,
                            size: 15, color: AppColors.black),
                        SizedBox(width: 4),
                        Text(
                          'CAGE',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
