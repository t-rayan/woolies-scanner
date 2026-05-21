import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/fge_model.dart';
import 'fge_provider.dart';

class FgeScreen extends ConsumerStatefulWidget {
  const FgeScreen({super.key});

  @override
  ConsumerState<FgeScreen> createState() => _FgeScreenState();
}

class _FgeScreenState extends ConsumerState<FgeScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  bool _isProcessing = false;
  String? _expandedSectionId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) return;

      setState(() => _isProcessing = true);
      ref.read(fgeSearchQueryProvider.notifier).state = '';
      _searchController.clear();
      _expandedSectionId = null;

      await ref
          .read(fgePlanogramProvider.notifier)
          .processImage(File(image.path));

      if (mounted) setState(() => _isProcessing = false);
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fgeAsync = ref.watch(fgePlanogramProvider);
    final searchQuery = ref.watch(fgeSearchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'FGE PLANOGRAM',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.black,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.black),
              onPressed: _pickAndProcessImage,
              tooltip: 'Upload FGE Sheet',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar (shown when data is loaded)
          if (fgeAsync.valueOrNull != null) _buildSearchBar(),

          // Main content
          Expanded(
            child: fgeAsync.when(
              data: (planogram) {
                if (planogram == null) return _buildEmptyState();
                final sections = ref.watch(fgeFilteredSectionsProvider);

                if (sections.isEmpty && searchQuery.isNotEmpty) {
                  return _buildNoResults();
                }

                return _buildSectionList(planogram, sections);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.black),
              ),
              error: (error, _) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppColors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (value) =>
            ref.read(fgeSearchQueryProvider.notifier).state = value,
        decoration: InputDecoration(
          hintText: 'SEARCH REF NUMBER OR PRODUCT NAME...',
          hintStyle: const TextStyle(color: AppColors.grey, fontSize: 11),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.black, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon:
                      const Icon(Icons.clear, size: 18, color: AppColors.grey),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(fgeSearchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.lightGrey.withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_rounded,
                size: 80, color: AppColors.lightGrey),
            const SizedBox(height: 24),
            const Text(
              'FGE PLANOGRAM',
              style: TextStyle(
                color: AppColors.black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upload a photo of the Front Gondola End sheet\n'
              'to see FGE001–FGE012, ENT001 & Front of Store Bin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndProcessImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('UPLOAD FGE SHEET',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 64, color: AppColors.lightGrey),
          const SizedBox(height: 16),
          const Text(
            'NO MATCHES FOUND',
            style: TextStyle(
              color: AppColors.grey,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No products match "${_searchController.text}"',
            style: const TextStyle(color: AppColors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final displayMessage = error.contains('ApiException')
        ? 'API Error — Check your API key and model access.'
        : error.contains('FormatException')
            ? 'Could not parse the sheet. Try a clearer photo.'
            : 'Something went wrong. Try again.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'PARSE FAILED',
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndProcessImage,
              icon: const Icon(Icons.refresh),
              label: const Text('TRY AGAIN',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionList(FgePlanogram planogram, List<FgeSection> sections) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header bar with stats
        _buildStatsHeader(planogram),
        const SizedBox(height: 16),

        // Section list
        ...sections.map((section) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSectionCard(section),
            )),
      ],
    );
  }

  Widget _buildStatsHeader(FgePlanogram planogram) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: AppColors.white, size: 14),
          const SizedBox(width: 8),
          Text(
            planogram.planogramDate,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          _StatChip(label: '${planogram.totalSections} SECTIONS'),
          const SizedBox(width: 6),
          _StatChip(label: '${planogram.totalProducts} ITEMS'),
        ],
      ),
    );
  }

  /// Renders a single section card with layout-adaptive content.
  Widget _buildSectionCard(FgeSection section) {
    final isExpanded = _expandedSectionId == section.id;
    final hasAlerts = section.hasAddedItems || section.hasRemovedItems;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: isExpanded ? AppColors.black : AppColors.lightGrey,
          width: isExpanded ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header (always visible)
          _buildSectionHeader(section, isExpanded, hasAlerts),

          // Expandable content
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.lightGrey),
            _buildSectionContent(section),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      FgeSection section, bool isExpanded, bool hasAlerts) {
    return InkWell(
      onTap: () {
        setState(() {
          _expandedSectionId =
              _expandedSectionId == section.id ? null : section.id;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Layout type icon
            _buildLayoutIcon(section.layoutType),
            const SizedBox(width: 12),

            // Section info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        section.id.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppColors.black,
                        ),
                      ),
                      if (hasAlerts) ...[
                        const SizedBox(width: 8),
                        if (section.hasAddedItems)
                          const _AlertChip(
                            label: 'ADDED',
                            color: Colors.blue,
                          ),
                        if (section.hasRemovedItems) ...[
                          const SizedBox(width: 4),
                          const _AlertChip(
                            label: 'REMOVED',
                            color: Colors.red,
                          ),
                        ],
                      ],
                    ],
                  ),
                  if (section.header.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      section.header,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.grey.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Product count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${section.totalProducts}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayoutIcon(FgeLayoutType type) {
    IconData icon;
    switch (type) {
      case FgeLayoutType.verticalBulk:
        icon = Icons.vertical_align_center_rounded;
      case FgeLayoutType.sideStack:
        icon = Icons.view_column_rounded;
      case FgeLayoutType.entranceBin:
        icon = Icons.store_rounded;
      case FgeLayoutType.standardShelved:
        icon = Icons.view_stream_rounded;
      case FgeLayoutType.unknown:
        icon = Icons.help_outline_rounded;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: AppColors.black),
    );
  }

  /// Adaptive content rendering based on layout type.
  Widget _buildSectionContent(FgeSection section) {
    switch (section.layoutType) {
      case FgeLayoutType.standardShelved:
        return _buildShelvedContent(section);
      case FgeLayoutType.verticalBulk:
        return _buildVerticalBulkContent(section);
      case FgeLayoutType.sideStack:
        return _buildSideStackContent(section);
      case FgeLayoutType.entranceBin:
        return _buildVerticalBulkContent(section);
      case FgeLayoutType.unknown:
        return _buildVerticalBulkContent(section);
    }
  }

  /// Renders standard shelved layout (shelves with levels).
  Widget _buildShelvedContent(FgeSection section) {
    if (section.shelves.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No shelf data available',
          style: TextStyle(
              color: AppColors.grey, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: section.shelves.map((shelf) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ShelfWidget(shelf: shelf),
          );
        }).toList(),
      ),
    );
  }

  /// Renders vertical bulk layout (items in a single column).
  Widget _buildVerticalBulkContent(FgeSection section) {
    if (section.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No items listed',
          style: TextStyle(
              color: AppColors.grey, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.lightGrey, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            // "Vertical Bulk" badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.vertical_align_center_rounded,
                      color: AppColors.white, size: 12),
                  SizedBox(width: 6),
                  Text(
                    'VERTICAL LAYOUT',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Items
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: section.items.asMap().entries.map((entry) {
                  final item = entry.value;
                  final isLast = entry.key == section.items.length - 1;
                  return Column(
                    children: [
                      _ItemRow(item: item),
                      if (!isLast) const Divider(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders side stack layout.
  Widget _buildSideStackContent(FgeSection section) {
    // Group items by position
    final grouped = <String, List<FgeItem>>{};
    for (final item in section.items) {
      grouped.putIfAbsent(item.position, () => []).add(item);
    }

    if (section.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No items listed',
          style: TextStyle(
              color: AppColors.grey, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: grouped.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border.all(color: AppColors.lightGrey, width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Position header
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.black,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Text(
                      entry.key.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  // Items
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: entry.value.asMap().entries.map((e) {
                        final isLast = e.key == entry.value.length - 1;
                        return Column(
                          children: [
                            _ItemRow(item: e.value),
                            if (!isLast) const Divider(height: 12),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A single shelf widget for standard shelved layout.
class _ShelfWidget extends StatelessWidget {
  final FgeShelf shelf;
  const _ShelfWidget({required this.shelf});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.lightGrey, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shelf header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.horizontal_rule,
                    color: AppColors.white, size: 12),
                const SizedBox(width: 6),
                Text(
                  'SHELF ${shelf.level}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '${shelf.items.length} item${shelf.items.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.6),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Items
          if (shelf.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Empty shelf',
                style: TextStyle(
                    color: AppColors.grey,
                    fontSize: 11,
                    fontStyle: FontStyle.italic),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: shelf.items.asMap().entries.map((entry) {
                  final item = entry.value;
                  final isLast = entry.key == shelf.items.length - 1;
                  return Column(
                    children: [
                      _ItemRow(item: item),
                      if (!isLast) const Divider(height: 12),
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

/// A single product item row with status alerts.
class _ItemRow extends StatelessWidget {
  final FgeItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator
        if (item.status != ItemStatus.normal)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: item.isRemoved
                    ? Colors.red.withValues(alpha: 0.15)
                    : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: item.isRemoved
                      ? Colors.red.withValues(alpha: 0.4)
                      : Colors.blue.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                item.isRemoved ? 'RMV' : 'ADD',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: item.isRemoved ? Colors.red[800] : Colors.blue[800],
                ),
              ),
            ),
          ),

        // Position indicator (for vertical_bulk / side_stack)
        if (item.position != 'default')
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _shortPosition(item.position),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: AppColors.grey,
              ),
            ),
          ),

        // Product info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: item.isRemoved ? Colors.red[700] : AppColors.black,
                  decoration:
                      item.isRemoved ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              _RefChip(ref: item.ref),
            ],
          ),
        ),
      ],
    );
  }

  String _shortPosition(String pos) {
    switch (pos.toLowerCase()) {
      case 'top':
        return 'TOP';
      case 'middle':
        return 'MID';
      case 'bottom':
        return 'BTM';
      case 'left_vertical':
      case 'left_stack':
        return 'L';
      case 'right_vertical':
      case 'right_stack':
        return 'R';
      default:
        return pos.substring(0, 1).toUpperCase();
    }
  }
}

/// Tappable ref number chip that copies to clipboard.
class _RefChip extends StatelessWidget {
  final String ref;
  const _RefChip({required this.ref});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (ref.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: ref));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('COPIED: $ref'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.black,
              duration: const Duration(milliseconds: 600),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.grey.withValues(alpha: 0.2)),
        ),
        child: Text(
          ref,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

/// Small stat chip for the header bar.
class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Alert chip for ADDED/REMOVED indicators.
class _AlertChip extends StatelessWidget {
  final String label;
  final Color color;
  const _AlertChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}
