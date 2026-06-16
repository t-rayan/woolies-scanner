import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../products/product_provider.dart';
import '../../widgets/search_result_tile.dart';
import '../../widgets/cage_fab_button.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(scanSearchQueryProvider.notifier).state = _searchController.text;
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(scanSearchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const CageFabButton(),
      appBar: AppBar(
        backgroundColor: AppColors.lightGrey,
        elevation: 0,
        centerTitle: false,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.black),
              onPressed: () {
                _searchController.clear();
                ref.read(scanSearchQueryProvider.notifier).state = '';
              },
              tooltip: 'Clear search',
            ),
        ],
      ),
      body: searchQuery.trim().isEmpty
          ? _buildEmptyPrompt()
          : _buildSearchResults(searchQuery),
    );
  }

  Widget _buildEmptyPrompt() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: AppColors.lightGrey),
          SizedBox(height: 16),
          Text('SEARCH PRODUCTS',
              style: TextStyle(
                  color: AppColors.grey,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          SizedBox(height: 8),
          Text('Type a product name or ref number to begin.',
              style: TextStyle(color: AppColors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSearchResults(String query) {
    final searchAsync = ref.watch(searchProductsProvider);

    return searchAsync.when(
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
            return SearchResultTile(
                product: product, query: query, displayAisle: displayAisle);
          },
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.black)),
      error: (_, __) => const Center(child: Text('Search error')),
    );
  }
}
