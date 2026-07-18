import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/app_store.dart';
import '../theme/app_colors.dart';
import 'parcel_details_screen.dart';

class ScanParcelScreen extends StatefulWidget {
  static const route = '/scan';
  const ScanParcelScreen({super.key});

  @override
  State<ScanParcelScreen> createState() => _ScanParcelScreenState();
}

class _ScanParcelScreenState extends State<ScanParcelScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;
    _handleCode(rawValue.trim());
  }

  Future<void> _handleCode(String code) async {
    if (_handled) return;
    _handled = true;
    final parcel = await AppStore.instance.scanOrCreateParcel(code);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelDetailsScreen(parcelId: parcel.id),
      ),
    );
  }

  Future<void> _promptManualCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Parcel Code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. PRC1234567890'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty && mounted) {
      _handleCode(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Scan Parcel',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_alt_outlined),
            tooltip: 'Enter code manually',
            onPressed: _promptManualCode,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'Scan QR / Barcode on the parcel',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ScannerViewport(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ScannerViewport extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;

  const _ScannerViewport({required this.controller, required this.onDetect});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: AppColors.scannerOverlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
              errorBuilder: (context, error) => Container(
                color: AppColors.scannerOverlay,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Camera unavailable: ${error.errorCode.name}\nGrant camera permission in Settings and try again.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                ),
              ),
            ),

            IgnorePointer(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  children: [
                    ...List.generate(4, (i) {
                      final isTop = i < 2;
                      final isLeft = i % 2 == 0;
                      return Positioned(
                        top: isTop ? 0 : null,
                        bottom: isTop ? null : 0,
                        left: isLeft ? 0 : null,
                        right: isLeft ? null : 0,
                        child: _CornerBracket(top: isTop, left: isLeft),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // Flashlight pill
            Positioned(
              bottom: 24,
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: controller,
                builder: (context, state, _) {
                  final flashOn = state.torchState == TorchState.on;
                  return GestureDetector(
                    onTap: () => controller.toggleTorch(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            flashOn
                                ? 'Tap to turn off Flashlight'
                                : 'Tap to turn on Flashlight',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            flashOn
                                ? Icons.flashlight_on_rounded
                                : Icons.flashlight_off_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final bool top;
  final bool left;
  const _CornerBracket({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: AppColors.primary, width: 4);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: top ? BorderSide.none : side,
          left: left ? side : BorderSide.none,
          right: left ? BorderSide.none : side,
        ),
      ),
    );
  }
}
