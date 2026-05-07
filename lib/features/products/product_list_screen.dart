import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/product_model.dart';
import 'product_provider.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  final String? date;
  const ProductListScreen({super.key, this.date});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _clearDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RESET DATABASE'),
        content: const Text('This will delete ALL scanned products. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RESET', style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(localProductDatabaseProvider).clearAllData();
      ref.invalidate(planogramDatesProvider);
      ref.invalidate(totalDatabaseItemsProvider);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(scanSearchQueryProvider);
    final sheetsAsync = widget.date != null 
        ? ref.watch(planogramSheetsProvider(widget.date!))
        : const AsyncValue.data(['ALL']);

    return searchQuery.trim().isNotEmpty
        ? _buildSearchScaffold()
        : sheetsAsync.when(
            data: (sheets) => _buildTabbedScaffold(sheets),
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.black))),
            error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          );
  }

  Widget _buildSearchScaffold() {
    final searchAsync = ref.watch(searchProductsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: _buildSearchField(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => ref.read(scanSearchQueryProvider.notifier).state = '',
        ),
      ),
      body: _buildSearchView(searchAsync),
    );
  }

  Widget _buildTabbedScaffold(List<String> sheets) {
    return DefaultTabController(
      length: sheets.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            widget.date?.toUpperCase() ?? 'COLLECTIONS',
            style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.black),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.black),
              onPressed: _clearDatabase,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.black,
            labelColor: AppColors.black,
            unselectedLabelColor: AppColors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: sheets.map((s) => Tab(text: s.toUpperCase())).toList(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSearchField(),
            ),
            Expanded(
              child: TabBarView(
                children: sheets.map((s) => _SheetTabView(date: widget.date!, sheet: s)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => ref.read(scanSearchQueryProvider.notifier).state = value,
      decoration: InputDecoration(
        hintText: 'SEARCH PRODUCTS...',
        hintStyle: const TextStyle(color: AppColors.grey, fontSize: 12),
        prefixIcon: const Icon(Icons.search, color: AppColors.black),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSearchView(AsyncValue<List<Product>> searchAsync) {
    return searchAsync.when(
      data: (products) => ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: products.length,
        separatorBuilder: (_, __) => const Divider(color: AppColors.lightGrey),
        itemBuilder: (context, index) => _ProductTile(product: products[index], showAisle: true),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.black)),
      error: (e, _) => Center(child: Text('Search error')),
    );
  }
}

class _SheetTabView extends ConsumerWidget {
  final String date;
  final String sheet;
  const _SheetTabView({required this.date, required this.sheet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(groupedProductsBySheetProvider((date: date, sheet: sheet)));

    return groupedAsync.when(
      data: (groups) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: groups.length,
        itemBuilder: (context, index) => _AisleCard(group: groups[index]),
      ),
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.black)),
      error: (e, _) => Center(child: Text('Error loading $sheet')),
    );
  }
}

class _AisleCard extends StatelessWidget {
  final AisleProductGroup group;
  const _AisleCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.black, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: AppColors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(9))),
            child: Row(
              children: [
                const Icon(Icons.shelves, color: AppColors.white, size: 16),
                const SizedBox(width: 8),
                Text(group.aisle.toUpperCase(), style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: group.products.map((p) => _ProductTile(product: p)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final bool showAisle;
  const _ProductTile({required this.product, this.showAisle = false});

  @override
  Widget build(BuildContext context) {
    final refs = product.barcode?.split(',').map((e) => e.trim()).toList() ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (showAisle) Text('AISLE: ${product.aisle}', style: const TextStyle(fontSize: 10, color: AppColors.grey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: refs.map((ref) => _RefChip(ref: ref)).toList(),
          ),
        ],
      ),
    );
  }
}

class _RefChip extends StatelessWidget {
  final String ref;
  const _RefChip({required this.ref});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: ref));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('COPIED $ref'), duration: const Duration(milliseconds: 500)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(4)),
        child: Text(ref, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
