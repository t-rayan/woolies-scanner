import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../products/product_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _deleteCollection(BuildContext context, WidgetRef ref, String date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE COLLECTION'),
        content: Text('Are you sure you want to delete all products from $date?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(localProductDatabaseProvider).deleteByDate(date);
      ref.invalidate(planogramDatesProvider);
      ref.invalidate(totalDatabaseItemsProvider);
      ref.invalidate(groupedProductsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbCountAsync = ref.watch(totalDatabaseItemsProvider);
    final datesAsync = ref.watch(planogramDatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'WOOLIES SCANNER',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: dbCountAsync.when(
        data: (count) {
          if (count == 0) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.lightGrey),
                  SizedBox(height: 16),
                  Text(
                    'No database',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return datesAsync.when(
            data: (dates) => _buildMinimalList(context, ref, dates, count),
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.black)),
            error: (e, st) => const Center(child: Text('Error loading database')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.black)),
        error: (e, st) => const Center(child: Text('Error loading database')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scanner'),
        backgroundColor: AppColors.black,
        child: const Icon(Icons.qr_code_scanner, color: AppColors.white),
      ),
    );
  }

  Widget _buildMinimalList(BuildContext context, WidgetRef ref, List<String> dates, int totalCount) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Text(
              'SAVED COLLECTIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.grey,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            Text(
              '$totalCount ITEMS',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...dates.map((date) => _buildDateItem(context, ref, date)),
      ],
    );
  }

  Widget _buildDateItem(BuildContext context, WidgetRef ref, String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lightGrey, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => context.push('/database?date=$date'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined, size: 24, color: AppColors.black),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    date,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.grey, size: 20),
                  onPressed: () => _deleteCollection(context, ref, date),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
