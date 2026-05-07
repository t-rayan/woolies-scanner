import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/product_model.dart';
import '../../core/services/claude_service.dart';
import '../../core/services/local_product_database.dart';
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
  File? _selectedFile;

  Future<void> _pickAndProcessFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() {
      _selectedFile = File(result.files.single.path!);
      _isProcessing = true;
      _statusMessage = 'Analyzing planogram...';
    });

    try {
      final apiKey = 'sk-ant-api03-...'; // In a real app, this would be from .env
      final claudeService = ClaudeService(apiKey);
      
      final results = await claudeService.analyzeImage(_selectedFile!);
      
      setState(() => _statusMessage = 'Saving to database...');

      // Correctly convert Map results to Product objects
      final List<Product> scannedProducts = results.map((r) => Product.fromMap(r)).toList();
      
      if (scannedProducts.isNotEmpty) {
        await ref.read(localProductDatabaseProvider).insertProducts(scannedProducts);
        
        // Refresh all relevant providers
        ref.invalidate(planogramDatesProvider);
        ref.invalidate(totalDatabaseItemsProvider);
        ref.invalidate(groupedProductsProvider);
        
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Success! ${scannedProducts.length} items added.';
        });

        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () => context.pop());
        }
      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No products found in sheet.';
        });
      }
    } catch (e) {
      debugPrint('Scan Error: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SCAN SHEET', style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing) ...[
                const CircularProgressIndicator(color: AppColors.black),
                const SizedBox(height: 24),
                Text(_statusMessage ?? 'Processing...', 
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ] else ...[
                const Icon(Icons.upload_file_outlined, size: 80, color: AppColors.lightGrey),
                const SizedBox(height: 32),
                const Text(
                  'Upload Planogram Sheet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select a photo or PDF of the OGE/FGE sheet to extract all products.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.grey),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _pickAndProcessFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SELECT FILE', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 24),
                  Text(_statusMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
