import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../products/product_database_provider.dart';
import '../products/product_provider.dart';
import '../../widgets/search_fab_button.dart';
import '../../widgets/cage_fab_button.dart';

/// 🔒 Reactive Auth Provider listening to current session parameters
// 🔒 Reactive Auth Stream Provider listening to authentication state changes live
final authSessionProvider = StreamProvider<Session?>((ref) {
  return SupabaseService.instance.client.auth.onAuthStateChange
      .map((data) => data.session);
});

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
  Future<void> _deleteSheetCategory(
      BuildContext context, WidgetRef ref, String sheet) async {
    final label = sheet == 'FGE' ? 'FGE - Front & Entrance' : 'OGE - Back Ends';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DELETE COLLECTION',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Delete ALL $label products?\n\n'
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
      await ref.read(supabaseServiceProvider).deleteBySheet(sheet);
      ref.invalidate(sheetCountsProvider);
      ref.invalidate(totalDatabaseItemsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbCountAsync = ref.watch(totalDatabaseItemsProvider);
    final sheetCountsAsync = ref.watch(sheetCountsProvider);

    // 🔐 Read authentication session state parameters
    final authAsync = ref.watch(authSessionProvider);
    final bool isAdmin = authAsync.value != null;

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
          isAdmin
              ? IconButton(
                  icon:
                      const Icon(Icons.logout_rounded, color: AppColors.black),
                  tooltip: 'Admin Sign Out',
                  onPressed: () async {
                    await SupabaseService.instance.client.auth.signOut();
                    ref.invalidate(authSessionProvider);
                  },
                )
              : IconButton(
                  icon: const Icon(Icons.admin_panel_settings_outlined,
                      color: AppColors.black),
                  tooltip: 'Admin Sign In',
                  onPressed: () => context.push('/login'),
                ),
        ],
      ),
      body: dbCountAsync.when(
        data: (count) {
          return sheetCountsAsync.when(
            data: (sheetCounts) {
              final totalSheets = sheetCounts['FGE']! + sheetCounts['OGE']!;
              if (totalSheets == 0) return _buildEmptyState();
              return _buildSheetList(context, ref, sheetCounts, count, isAdmin);
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
                    ref.invalidate(sheetCountsProvider);
                  },
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
      ),
      // 🛠️ Dynamic Multi-tier Float system depending on platform layout structures
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CageFabButton(),
          const SizedBox(height: 16),
          const SearchFabButton(),
          if (isAdmin) ...[
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: 'scan',
              onPressed: () => context.push('/scanner'),
              backgroundColor: AppColors.black,
              elevation: 4,
              child: const Icon(Icons.qr_code_scanner, color: AppColors.white),
            ),
          ],
        ],
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
          Text('Tip: Log in as admin to scan promotional sheets.',
              style: TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSheetList(BuildContext context, WidgetRef ref,
      Map<String, int> sheetCounts, int totalCount, bool isAdmin) {
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
        _buildSheetFolder(
          context,
          ref,
          sheet: 'OGE',
          label: 'OGE - Back Ends',
          icon: Icons.shelves,
          count: sheetCounts['OGE'] ?? 0,
          isAdmin: isAdmin,
        ),
        const SizedBox(height: 12),
        _buildSheetFolder(
          context,
          ref,
          sheet: 'FGE',
          label: 'FGE - Front & Entrance',
          icon: Icons.storefront_rounded,
          count: sheetCounts['FGE'] ?? 0,
          isAdmin: isAdmin,
        ),
      ],
    );
  }

  /// Single sheet folder (FGE or OGE).
  Widget _buildSheetFolder(
    BuildContext context,
    WidgetRef ref, {
    required String sheet,
    required String label,
    required IconData icon,
    required int count,
    required bool isAdmin,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/database?sheet=$sheet');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.black, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
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
                    Text(label,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.black)),
                    const SizedBox(height: 4),
                    Text(
                      count == 0
                          ? 'No products'
                          : '$count product${count == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.grey,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (isAdmin && count > 0)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.grey, size: 22),
                  onPressed: () => _deleteSheetCategory(context, ref, sheet),
                ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
