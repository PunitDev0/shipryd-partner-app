import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:partner/features/parcel/domain/parcel_controller.dart';
import 'package:partner/features/parcel/presentation/parcel_received_screen.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/utils/formatters.dart';

class AddProofScreen extends StatefulWidget {
  static const route = '/add-proof';
  final String parcelId;
  const AddProofScreen({super.key, required this.parcelId});

  @override
  State<AddProofScreen> createState() => _AddProofScreenState();
}

class _AddProofScreenState extends State<AddProofScreen> {
  XFile? _photo;
  bool _saving = false;
  bool _paymentReceivedConfirmed = false;

  @override
  void initState() {
    super.initState();
    final parcel = ParcelController.findById(widget.parcelId);
    if (parcel != null && parcel.paymentMode != 'COD') {
      _paymentReceivedConfirmed = true;
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      XFile? picked;
      try {
        picked = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1600,
          imageQuality: 85,
        );
      } catch (_) {
        if (source == ImageSource.camera) {
          picked = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 1600,
            imageQuality: 85,
          );
        } else {
          rethrow;
        }
      }
      if (picked != null && mounted) {
        setState(() => _photo = picked);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access camera/gallery: $e')),
        );
      }
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ParcelController.completeDelivery(widget.parcelId, proofPath: _photo?.path);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ParcelReceivedScreen(parcelId: widget.parcelId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parcel = ParcelController.findById(widget.parcelId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Add Proof (Optional)',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 4),
              Text(
                'Add photo as proof of receiving',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_photo!.path),
                        width: 130,
                        height: 130,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (_photo != null) const SizedBox(width: 14),

                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _photo == null ? Icons.add_a_photo_outlined : Icons.add,
                        size: 32,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
              Text(
                'This helps in dispute resolution',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),

              // Payment Received Card
              if (parcel != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: parcel.paymentMode == 'COD'
                        ? const Color(0xFFFFF9E6)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: parcel.paymentMode == 'COD'
                          ? const Color(0xFFFFCC00).withValues(alpha: 0.35)
                          : const Color(0xFF22C55E).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            parcel.paymentMode == 'COD'
                                ? Icons.monetization_on_rounded
                                : Icons.check_circle_rounded,
                            color: parcel.paymentMode == 'COD'
                                ? const Color(0xFFD97706)
                                : const Color(0xFF15803D),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            parcel.paymentMode == 'COD'
                                ? 'Collect Cash Payment'
                                : 'Payment Status',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: parcel.paymentMode == 'COD'
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF166534),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (parcel.paymentMode == 'COD') ...[
                        Text(
                          'Please collect cash from the customer:',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatAmount(parcel.codAmount),
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _paymentReceivedConfirmed,
                                activeColor: AppColors.primary,
                                checkColor: Colors.black,
                                onChanged: (val) {
                                  setState(() {
                                    _paymentReceivedConfirmed = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _paymentReceivedConfirmed = !_paymentReceivedConfirmed;
                                  });
                                },
                                child: Text(
                                  'Confirm cash payment of ${formatAmount(parcel.codAmount)} received',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'This is a Prepaid order. Payment has been received digitally.',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_saving || !_paymentReceivedConfirmed) ? null : _finish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: (_saving || !_paymentReceivedConfirmed) ? null : _finish,
                child: Text(
                  'Skip',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
