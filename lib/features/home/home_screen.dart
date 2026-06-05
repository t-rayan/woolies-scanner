import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/product_model.dart';
import '../../core/services/supabase_service.dart';
import '../products/product_database_provider.dart';
import '../products/product_provider.dart';

/// Highlighted text span helper for search results - bold yellow on matches.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: (style ?? const TextStyle()).copyWith(
          backgroundColor: AppColors.highlightYellow,
          fontWeight: FontWeight.w900,
        ),
      ));

      start = index + query.length;
    }

    return Text.rich(TextSpan(children: spans));
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

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
    if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() => _isSearching = false);
    }
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    ref.read(scanSearchQueryProvider.notifier).state = '';
    setState(() => _isSearching = false);
  }

  Future<void> _deleteEntireDate(
      BuildContext context, WidgetRef ref, String date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE COLLECTION',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Delete ALL products scanned on $date?\n\n'
          'This action cannot be undone.',
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
      await ref.read(supabaseServiceProvider).deleteByDate(date);
      ref.invalidate(planogramDatesProvider);
      ref.invalidate(totalDatabaseItemsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbCountAsync = ref.watch(totalDatabaseItemsProvider);
    final datesAsync = ref.watch(planogramDatesProvider);
    final searchQuery = ref.watch(scanSearchQueryProvider);

    if (_isSearching && searchQuery.trim().isNotEmpty) {
      return _buildSearchScaffold(searchQuery);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Search all products...',
                  hintStyle: TextStyle(color: AppColors.grey, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : const Text(
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
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.black),
              onPressed: _closeSearch,
              tooltip: 'Close search',
            ),
        ],
      ),
      body: dbCountAsync.when(
        data: (count) {
          return datesAsync.when(
            data: (dates) {
              if (dates.isEmpty) return _buildEmptyState();
              return _buildDateList(context, ref, dates, count);
            },
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.black)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.grey),
                    const SizedBox(height: 12),
                    Text('$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.black)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 64, color: AppColors.grey),
                const SizedBox(height: 16),
                const Text('DATABASE ERROR',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.black)),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.grey, fontSize: 12),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(totalDatabaseItemsProvider);
                    ref.invalidate(planogramDatesProvider);
                  },
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: kIsWeb
          // Web: only show search (scan doesn't work on web due to CORS)
          ? FloatingActionButton(
              heroTag: 'search',
              onPressed: _startSearch,
              backgroundColor: AppColors.black,
              elevation: 4,
              child: const Icon(Icons.search_rounded, color: AppColors.white),
            )
          // Mobile: show both search (mini) + scan FABs
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'search',
                  onPressed: _startSearch,
                  backgroundColor: AppColors.black,
                  elevation: 4,
                  mini: true,
                  child:
                      const Icon(Icons.search_rounded, color: AppColors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'scan',
                  onPressed: () => context.push('/scanner'),
                  backgroundColor: AppColors.black,
                  elevation: 4,
                  child:
                      const Icon(Icons.qr_code_scanner, color: AppColors.white),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchScaffold(String query) {
    final searchAsync = ref.watch(searchProductsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          style: const TextStyle(
              color: AppColors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: 'Search all products...',
            hintStyle: TextStyle(color: AppColors.grey, fontSize: 14),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.black),
            onPressed: _closeSearch,
            tooltip: 'Close search',
          ),
        ],
      ),
      body: searchAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 64, color: AppColors.lightGrey),
                  const SizedBox(height: 16),
                  const Text('NO MATCHES FOUND',
                      style: TextStyle(
                          color: AppColors.grey,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('No products match "$query"',
                      style:
                          const TextStyle(color: AppColors.grey, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: products.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.lightGrey, height: 20),
            itemBuilder: (context, index) {
              final product = products[index];
              final displayAisle = product.aisle?.toUpperCase() ??
                  product.sheetName?.toUpperCase() ??
                  'GEN';
              return _SearchResultTile(
                  product: product, query: query, displayAisle: displayAisle);
            },
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.black)),
        error: (_, __) => const Center(child: Text('Search error')),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: AppColors.lightGrey),
          SizedBox(height: 16),
          Text('No scans found',
              style: TextStyle(
                  color: AppColors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 24),
          Text('Tip: Tap the + button to scan a promo sheet.',
              style: TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDateList(
      BuildContext context, WidgetRef ref, List<String> dates, int totalCount) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Text('SAVED COLLECTIONS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.grey,
                    letterSpacing: 1.0)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.black,
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$totalCount TOTAL ITEMS',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...dates.map((date) => _buildDateFolder(context, ref, date)),
      ],
    );
  }

  /// Single date folder — clicking it navigates to folder selection screen.
  Widget _buildDateFolder(BuildContext context, WidgetRef ref, String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          final encodedDate = Uri.encodeComponent(date);
          context.push('/database?date=$encodedDate');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.lightGrey, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_rounded,
                  size: 32, color: AppColors.black),
              const SizedBox(width: 16),
              Expanded(
                child: Text(date,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.black)),
              ),
              if (!kIsWeb)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.grey, size: 22),
                  onPressed: () => _deleteEntireDate(context, ref, date),
                ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

/// Provider to fetch grouped counts per sheet for a date.
final groupedCountsProvider =
    FutureProvider.family<List<SheetCategorySummary>, String>(
        (ref, date) async {
  final svc = ref.read(supabaseServiceProvider);
  return svc.fetchGroupedCountsByDate(date);
});

/// Ends that don't belong to this store — shown as disabled/grayed out.
const _disabledEnds = <String>{'FGE011', 'FGE012', 'OGE011', 'OGE012'};

/// Returns true if the aisle ID is a disabled end (not belonging to this store).
bool _isDisabledEnd(String aisle) =>
    _disabledEnds.contains(aisle.toUpperCase());

/// A search result tile with yellow-highlighted matching text and prominent aisle badge (B&W).
class _SearchResultTile extends StatelessWidget {
  final Product product;
  final String query;
  final String displayAisle;

  const _SearchResultTile({
    required this.product,
    required this.query,
    required this.displayAisle,
  });

  @override
  Widget build(BuildContext context) {
    final refs =
        product.barcode?.split(',').map((e) => e.trim()).toList() ?? [];
    final isEnt = displayAisle.startsWith('ENT');
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
                  text: product.name.toUpperCase(),
                  query: query.toUpperCase(),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
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
                        .map((ref) => _HomeRefChip(ref: ref, query: query))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Aisle badge on the right (consistent with folder search)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: disabled
                  ? AppColors.grey
                  : (isEnt ? AppColors.black : AppColors.darkGrey),
              borderRadius: BorderRadius.circular(8),
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
    );
  }
}

/// Ref chip with optional highlight for search matches.
class _HomeRefChip extends StatelessWidget {
  final String ref;
  final String query;
  const _HomeRefChip({required this.ref, this.query = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.grey.withValues(alpha: 0.2)),
      ),
      child: query.isNotEmpty && ref.toLowerCase().contains(query.toLowerCase())
          ? HighlightedText(
              text: ref,
              query: query,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black),
            )
          : Text(ref,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black)),
    );
  }
}
