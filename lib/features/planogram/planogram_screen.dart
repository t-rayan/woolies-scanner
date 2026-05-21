import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/planogram_model.dart';
import 'planogram_provider.dart';

class PlanogramScreen extends ConsumerStatefulWidget {
  const PlanogramScreen({super.key});

  @override
  ConsumerState<PlanogramScreen> createState() => _PlanogramScreenState();
}

class _PlanogramScreenState extends ConsumerState<PlanogramScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _selectedAisleId;
  bool _isProcessing = false;

  Future<void> _pickAndProcessImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) return;

      setState(() => _isProcessing = true);

      await ref
          .read(planogramProvider.notifier)
          .processImage(image);

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planogramAsync = ref.watch(planogramProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'PLANOGRAM',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 20,
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
              tooltip: 'Upload Planogram Sheet',
            ),
        ],
      ),
      body: planogramAsync.when(
        data: (planogram) {
          if (planogram == null) {
            return _buildEmptyState();
          }
          return _buildPlanogramGrid(planogram);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.black),
        ),
        error: (error, _) => _buildErrorState(error.toString()),
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
            const Icon(Icons.grid_view_rounded,
                size: 80, color: AppColors.lightGrey),
            const SizedBox(height: 24),
            const Text(
              'NO PLANOGRAM LOADED',
              style: TextStyle(
                color: AppColors.black,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upload a photo of the Weekly Sales Plan sheet\n'
              'to see OGE001–OGE012 layout.',
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
              label: const Text('UPLOAD SHEET',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
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
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('PARSE FAILED',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(displayMessage, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndProcessImage,
              icon: const Icon(Icons.refresh),
              label: const Text('TRY AGAIN',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanogramGrid(Planogram planogram) {
    return Column(
      children: [
        _buildHeaderBar(planogram),
        Expanded(child: _buildGrid(planogram)),
      ],
    );
  }

  Widget _buildHeaderBar(Planogram planogram) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppColors.black,
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: AppColors.white, size: 14),
          const SizedBox(width: 8),
          Text(planogram.planogramDate,
              style: const TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          _headerChip('${planogram.totalProducts} ITEMS'),
          const SizedBox(width: 8),
          _headerChip('${planogram.totalAisles} AISLES'),
        ],
      ),
    );
  }

  Widget _headerChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGrid(Planogram planogram) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: planogram.aisles.length,
            itemBuilder: (context, index) {
              final aisle = planogram.aisles[index];
              final isSelected = _selectedAisleId == aisle.id;
              return _AisleGridTile(
                aisle: aisle,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedAisleId =
                        _selectedAisleId == aisle.id ? null : aisle.id;
                  });
                },
              );
            },
          ),
          if (_selectedAisleId != null)
            _buildSelectedAisleDetail(planogram),
        ],
      ),
    );
  }

  Widget _buildSelectedAisleDetail(Planogram planogram) {
    final aisle = planogram.aisles.firstWhere(
      (a) => a.id == _selectedAisleId,
      orElse: () => const PlanogramAisle(id: '', promoType: '', shelves: []),
    );
    if (aisle.id.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _AisleDetailCard(aisle: aisle),
    );
  }
}

class _AisleGridTile extends StatelessWidget {
  final PlanogramAisle aisle;
  final bool isSelected;
  final VoidCallback onTap;
  const _AisleGridTile({required this.aisle, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.white,
          border: Border.all(
            color: isSelected ? AppColors.black : AppColors.lightGrey,
            width: isSelected ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(aisle.id.replaceAll('OGE', ''),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? AppColors.white : AppColors.black)),
            const SizedBox(height: 4),
            Text(aisle.promoType.isNotEmpty ? aisle.promoType : '—',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.white.withValues(alpha: 0.7)
                        : AppColors.grey),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.white.withValues(alpha: 0.2)
                    : AppColors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${aisle.shelves.length} shelves',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.white : AppColors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AisleDetailCard extends StatelessWidget {
  final PlanogramAisle aisle;
  const _AisleDetailCard({required this.aisle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.black, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shelves, color: AppColors.white, size: 18),
                const SizedBox(width: 10),
                Text(aisle.id.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(aisle.promoType.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: aisle.shelves.asMap().entries.map((entry) {
                final shelf = entry.value;
                final isLast = entry.key == aisle.shelves.length - 1;
                return Column(
                  children: [
                    _ShelfRow(shelf: shelf),
                    if (!isLast) const SizedBox(height: 12),
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

class _ShelfRow extends StatelessWidget {
  final PlanogramShelf shelf;
  const _ShelfRow({required this.shelf});

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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.horizontal_rule, color: AppColors.white, size: 12),
                const SizedBox(width: 6),
                Text('SHELF ${shelf.level}',
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
                const Spacer(),
                Text('${shelf.products.length} product${shelf.products.length == 1 ? '' : 's'}',
                    style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (shelf.products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No products listed',
                  style: TextStyle(
                      color: AppColors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: shelf.products.asMap().entries.map((entry) {
                  final product = entry.value;
                  final isMultiColumn = shelf.products.length > 1;
                  final isLast = entry.key == shelf.products.length - 1;
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMultiColumn)
                            Container(
                              margin: const EdgeInsets.only(right: 10, top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.black.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('${entry.key + 1}',
                                  style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.grey)),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name.toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.black)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: product.ref.map((ref) {
                                    return _RefChip(ref: ref);
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!isLast) const Divider(height: 16),
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

class _RefChip extends StatelessWidget {
  final String ref;
  const _RefChip({required this.ref});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final data = ref.trim();
        if (data.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('COPIED: $data'),
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
        child: Text(ref,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.black)),
      ),
    );
  }
}
