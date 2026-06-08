import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:woolies_scanner/core/services/supabase_service.dart';

import '../../core/models/product_model.dart';
import '../../core/services/claude_service.dart';
import '../products/product_database_provider.dart';
import '../products/product_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  bool _isProcessing = false;
  String? _statusMessage;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndProcessImage({required ImageSource source}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );

      if (image == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Processing image...';
        _errorMessage = null;
      });

      final claudeService = ClaudeService();

      // Image preprocessing happens inside analyzeImage (EXIF + resize to 2576px)
      setState(() => _statusMessage = 'Analyzing sheet...');

      final results = await claudeService.analyzeImage(
          image, ref.read(supabaseServiceProvider).client);

      if (results.isEmpty) {
        throw Exception(
            'AI could not detect any products. Please ensure the image is clear and well-lit.');
      }

      final String today = DateFormat('dd/MM/yyyy').format(DateTime.now());

      // Collect all dates to check for duplicates
      final datesFound = <String>{};

      final List<Product> scannedProducts = results.map<Product>((r) {
        final aisleStr =
            (r['aisle'] ?? 'GENERAL').toString().toUpperCase().trim();
        String planogramDate = (r['planogram_date'] ?? today).toString().trim();
        if (planogramDate.length < 5) planogramDate = today;

        // --- ROUTING RULES ---
        // OGE: ONLY OGE001-OGE012
        // FGE: Everything else — FGE boxes, ENT, POS, BIN, Front of Store
        String sheetName = 'OGE';
        if (aisleStr.startsWith('FGE') ||
            aisleStr.startsWith('ENT') ||
            aisleStr.startsWith('POS') ||
            aisleStr.startsWith('BIN') ||
            aisleStr.startsWith('FRONT OF STORE') ||
            aisleStr.contains('FLEXI')) {
          sheetName = 'FGE';
        }

        datesFound.add(planogramDate);

        return Product(
          name: r['name'] ?? 'Unknown Product',
          barcode: r['barcode'],
          aisle: aisleStr,
          planogramDate: planogramDate,
          sheetName: sheetName,
          scanDate: DateTime.now(),
        );
      }).toList();

      setState(
          () => _statusMessage = 'Saving ${scannedProducts.length} items...');

      await ref.read(supabaseServiceProvider).insertProducts(scannedProducts);

      // Force immediate recomputation so home screen shows updated data on pop.
      ref.invalidate(planogramDatesProvider);
      ref.invalidate(totalDatabaseItemsProvider);
      ref.invalidate(groupedProductsBySheetProvider);
      // Eagerly re-read to flush stale cache before navigation.
      await ref.read(planogramDatesProvider.future);
      await ref.read(totalDatabaseItemsProvider.future);

      if (mounted) {
        final msg = 'SAVED ${scannedProducts.length} ITEMS';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _statusMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('NEW SCAN',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: _isProcessing
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.black),
                    const SizedBox(height: 24),
                    Text(_statusMessage ?? 'Processing...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_errorMessage != null) ...[
                      const Icon(Icons.error_outline_rounded,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'SCAN FAILED',
                        style: TextStyle(
                            color: Colors.red[900],
                            fontWeight: FontWeight.w900,
                            fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                    ] else ...[
                      const Icon(Icons.document_scanner_rounded,
                          size: 100, color: Colors.grey),
                      const SizedBox(height: 32),
                      const Text(
                        'Upload Promo Sheet',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select a photo of your OGE or FGE sheet to extract details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 48),
                    ],
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _pickAndProcessImage(
                                  source: ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_rounded),
                              label: const Text('CAMERA',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 20),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () => _pickAndProcessImage(
                                  source: ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_rounded),
                              label: Text(
                                  _errorMessage != null
                                      ? 'TRY AGAIN'
                                      : 'GALLERY',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 20),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
