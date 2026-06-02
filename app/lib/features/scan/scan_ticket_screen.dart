import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'detected_products_screen.dart';

class ScanTicketScreen extends StatelessWidget {
  const ScanTicketScreen({super.key});

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
                            Text('SUPERMERCADO FRESCO', style: TextStyle(fontWeight: FontWeight.w900)),
                            Divider(),
                            Text('Arándanos 125 g        2,49 €'),
                            Text('Yogur natural          0,69 €'),
                            Text('Pechuga pollo 500 g    3,79 €'),
                            Text('Lechuga                0,99 €'),
                            Spacer(),
                            Divider(),
                            Text('TOTAL                  7,96 €', style: TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
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
                        child: const Text('Coloca el ticket dentro del marco', style: TextStyle(color: Colors.white)),
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
                    onPressed: () {},
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Importar foto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.flash_on_rounded),
                    label: const Text('Flash'),
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
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DetectedProductsScreen()));
                },
                child: const Icon(Icons.document_scanner_rounded, size: 34),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
