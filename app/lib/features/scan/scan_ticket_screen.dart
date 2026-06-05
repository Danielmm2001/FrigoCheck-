import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/receipt_analysis_model.dart';
import '../../data/services/api_service.dart';
import 'detected_products_screen.dart';

class ScanTicketScreen extends StatefulWidget {
  const ScanTicketScreen({super.key});

  @override
  State<ScanTicketScreen> createState() => _ScanTicketScreenState();
}

class _ScanTicketScreenState extends State<ScanTicketScreen> {
  final ApiService _apiService = const ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isAnalyzing = false;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
    });
  }

  Future<void> _analyzeSelectedImage() async {
    final image = _selectedImage;
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero selecciona una foto del ticket')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final ReceiptAnalysisModel analysis = await _apiService.analyzeReceiptImage(image);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DetectedProductsScreen(analysis: analysis),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())) ,
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear ticket')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_selectedImage == null)
                      Container(
                        width: 230,
                        height: 360,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.primary, width: 3),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SELECCIONA UN TICKET', style: TextStyle(fontWeight: FontWeight.w900)),
                              Divider(),
                              Text('1. Pulsa importar foto'),
                              Text('2. Elige un ticket'),
                              Text('3. Analízalo con IA'),
                              Spacer(),
                              Divider(),
                              Text('FrigoCheck lo convertirá en productos', style: TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      )
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.file(
                          _selectedImage!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Positioned(
                      top: 22,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withOpacity(.72),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _selectedImage == null ? 'Selecciona una foto del ticket' : 'Ticket listo para analizar',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    if (_isAnalyzing)
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.45),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 18),
                            Text('Analizando ticket con IA...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Importar foto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Cámara'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 82,
              height: 82,
              child: FloatingActionButton(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: _isAnalyzing ? null : _analyzeSelectedImage,
                child: _isAnalyzing
                    ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Icon(Icons.document_scanner_rounded, size: 34),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
