import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/product_model.dart';

import '../../core/services/supabase_service.dart';
import '../../features/home/home_screen.dart';
import '../products/product_database_provider.dart';
import '../products/product_provider.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  final String? date;
  final String? sheet;
  const ProductListScreen({super.key, this.date, this.sheet});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(scanSearchQueryProvider.notifier).state = _searchController.text;
  }

  void _onFocusChanged() {
    if (!_searchFocusNode.hasFocus &&
        _searchController.text.isEmpty &&
        _searchActive) {
      setState(() => _searchActive = false);
    }
  }

  void _activateSearch() {
    setState(() => _searchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _deactivateSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    ref.read(scanSearchQueryProvider.notifier).state = '';
    setState(() => _searchActive = false);
  }

  Future<void> _deleteSheetCategory(
      String date, SheetCategorySummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE ALL DATA',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Delete all ${summary.displayLabel} products from $date?\n\n'
          '${summary.productCount} items will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('CANCEL', style: TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(supabaseServiceProvider)
          .deleteByDateAndSheet(date, summary.sheetName);
      ref.invalidate(planogramDatesProvider);
      ref.invalidate(totalDatabaseItemsProvider);
      ref.invalidate(groupedCountsProvider(date));
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final String cleanDate = Uri.decodeComponent(widget.date ?? '').trim();
    final String cleanSheet = (widget.sheet ?? '').toUpperCase().trim();
    final searchQuery = ref.watch(scanSearchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: _searchActive
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(color: AppColors.grey, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : Text(
                cleanDate.toUpperCase(),
                style: const TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16),
              ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_searchActive)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.black),
              onPressed: _deactivateSearch,
              tooltip: 'Close search',
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.black),
              onPressed: _activateSearch,
              tooltip: 'Search',
            ),
        ],
      ),
      body: _buildBody(cleanDate, cleanSheet, searchQuery),
    );
  }

  Widget _buildBody(String date, String sheet, String searchQuery) {
    // If sheet IS specified, show the products
    if (sheet.isNotEmpty && searchQuery.trim().isEmpty) {
      return _buildSheetView(date: date, sheet: sheet);
    }

    // If search is active, show search results
    if (searchQuery.trim().isNotEmpty) {
      return _buildSearchResults(searchQuery);
    }

    // No sheet specified — show folder selection (OGE / FGE cards)
    return _buildFolderSelection(date);
  }

  /// Shows OGE / FGE folder cards for the given date.
  Widget _buildFolderSelection(String date) {
    final sheetsAsync = ref.watch(groupedCountsProvider(date));

    return sheetsAsync.when(
      data: (summaries) {
        if (summaries.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 48, color: AppColors.lightGrey),
                SizedBox(height: 16),
                Text('NO PRODUCTS FOUND',
                    style: TextStyle(
                        color: AppColors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('SELECT CATEGORY',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.grey,
                    letterSpacing: 1.0)),
            const SizedBox(height: 20),
            ...summaries.map((summary) => _buildFolderCard(date, summary)),
          ],
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.black)),
      error: (_, __) => const Center(child: Text('Error loading data')),
    );
  }

  Widget _buildFolderCard(String date, SheetCategorySummary summary) {
    final isOge = summary.sheetName == 'OGE';
    final icon = isOge ? Icons.shelves : Icons.storefront_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          final encodedDate = Uri.encodeComponent(date);
          context
              .push('/database?date=$encodedDate&sheet=${summary.sheetName}');
        },
        onLongPress: () => _deleteSheetCategory(date, summary),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.black, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: AppColors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.displayLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.black)),
                      const SizedBox(height: 4),
                      Text(
                          '${summary.productCount} product${summary.productCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.grey,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetView({required String date, required String sheet}) {
    final groupedAsync =
        ref.watch(groupedProductsBySheetProvider((date: date, sheet: sheet)));

    return groupedAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 48, color: AppColors.lightGrey),
                const SizedBox(height: 16),
                Text('NO PRODUCTS IN ${sheet.toUpperCase()}',
                    style: const TextStyle(
                        color: AppColors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('DATE: $date',
                    style:
                        const TextStyle(fontSize: 10, color: AppColors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: groups.length,
          itemBuilder: (context, index) =>
              _AisleCard(group: groups[index], query: ''),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.black)),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSearchResults(String query) {
    final searchAsync = ref.watch(searchProductsProvider);

    return searchAsync.when(
      data: (products) {
        if (products.isEmpty)
          return const Center(child: Text('NO MATCHES FOUND'));
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: products.length,
          separatorBuilder: (_, __) =>
              const Divider(color: AppColors.lightGrey),
          itemBuilder: (context, index) => _ProductTile(
              product: products[index], query: query, showAisle: true),
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.black)),
      error: (_, __) => const Center(child: Text('Search error')),
    );
  }
}

class _AisleCard extends StatelessWidget {
  final AisleProductGroup group;
  final String query;
  const _AisleCard({required this.group, this.query = ''});

  /// Returns a human-readable display label for special sections.
  static String _displayLabel(String aisle) {
    switch (aisle) {
      case 'BIN':
        return 'FRONT OF STORE BIN';
      case 'POS':
        return 'POS - FLEXI STAND';
      default:
        return aisle.toUpperCase();
    }
  }

  /// Returns a descriptive icon for the section type.
  static IconData _sectionIcon(String aisle) {
    if (aisle == 'BIN') return Icons.inventory_rounded;
    if (aisle == 'POS') return Icons.storefront_rounded;
    if (aisle.startsWith('ENT')) return Icons.door_front_door_rounded;
    if (aisle.startsWith('FGE')) return Icons.shelves;
    return Icons.shelves;
  }

  /// Returns a subtle subtitle for the section.
  static String _sectionSubtitle(String aisle) {
    if (aisle == 'BIN') return 'Front of Store Display';
    if (aisle == 'POS') return 'Flexi Stand Unit';
    if (aisle.startsWith('ENT')) return 'Entrance Display';
    if (aisle.startsWith('FGE')) return 'Front Gondola End';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final aisle = group.aisle.toUpperCase();
    final label = _displayLabel(aisle);
    final icon = _sectionIcon(aisle);
    final subtitle = _sectionSubtitle(aisle);
    final isSpecialSection =
        ['BIN', 'POS'].contains(aisle) || aisle.startsWith('ENT');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: isSpecialSection ? AppColors.darkGrey : AppColors.black,
          width: isSpecialSection ? 2.5 : 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aisle header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSpecialSection ? AppColors.darkGrey : AppColors.black,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.white, size: 16),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.7),
                              fontSize: 8,
                              fontWeight: FontWeight.w500)),
                  ],
                ),
                const Spacer(),
                Text('${group.products.length} ITEMS',
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: group.products.asMap().entries.map((e) {
                final isLast = e.key == group.products.length - 1;
                return Column(
                  children: [
                    _ProductTile(product: e.value, query: query),
                    if (!isLast)
                      const Divider(color: AppColors.lightGrey, height: 24),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final String query;
  final bool showAisle;
  const _ProductTile({
    required this.product,
    this.query = '',
    this.showAisle = false,
  });

  @override
  Widget build(BuildContext context) {
    final refs =
        product.barcode?.split(',').map((e) => e.trim()).toList() ?? [];
    final displayAisle = product.aisle?.toUpperCase() ??
        product.sheetName?.toUpperCase() ??
        'GEN';
    final isEnt = displayAisle.startsWith('ENT');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: query.isNotEmpty
                  ? HighlightedText(
                      text: product.name.toUpperCase(),
                      query: query.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.black),
                    )
                  : Text(product.name.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.black)),
            ),
            if (showAisle)
              // Aisle badge — only shown in search results
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isEnt ? AppColors.black : AppColors.darkGrey,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(displayAisle,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: refs.map((ref) {
            if (query.isNotEmpty &&
                ref.toLowerCase().contains(query.toLowerCase())) {
              return _RefChipHighlighted(ref: ref, query: query);
            }
            return _RefChip(ref: ref);
          }).toList(),
        ),
      ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('COPIED: $ref'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.black,
            duration: const Duration(milliseconds: 600),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.grey.withValues(alpha: 0.2)),
        ),
        child: Text(ref,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _RefChipHighlighted extends StatelessWidget {
  final String ref;
  final String query;
  const _RefChipHighlighted({required this.ref, required this.query});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: ref));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('COPIED: $ref'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.black,
            duration: const Duration(milliseconds: 600),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.grey.withValues(alpha: 0.2)),
        ),
        child: HighlightedText(
          text: ref,
          query: query,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
