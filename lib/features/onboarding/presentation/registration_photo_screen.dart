import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import '../widgets/onboarding_step_indicator.dart';
import 'registration_kyc_screen.dart';

const _requirements = [
  'Face clearly visible',
  'No sunglasses',
  'Good lighting',
  'Recent photo',
];

/// Step 4 — Profile Photo. Camera-only capture (no gallery), so what's
/// uploaded is actually a fresh selfie rather than an old/edited image.
class RegistrationPhotoScreen extends StatefulWidget {
  const RegistrationPhotoScreen({super.key});

  @override
  State<RegistrationPhotoScreen> createState() => _RegistrationPhotoScreenState();
}

class _RegistrationPhotoScreenState extends State<RegistrationPhotoScreen> {
  bool _acknowledged = false;
  bool _uploading = false;
  String? _error;

  Future<void> _capture() async {
    if (!_acknowledged || _uploading) return;
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
              title: const Text('Choose from Gallery (Simulator Fallback)'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      setState(() {
        _uploading = true;
        _error = null;
      });
      XFile? picked;
      try {
        picked = await ImagePicker().pickImage(
          source: source,
          imageQuality: 85,
          preferredCameraDevice: CameraDevice.front,
        );
      } catch (_) {
        if (source == ImageSource.camera) {
          picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
        } else {
          rethrow;
        }
      }
      if (picked == null) return;
      await AppStore.instance.uploadDocumentFile('photo', File(picked.path));
    } catch (e) {
      setState(() => _error = 'Could not capture/upload photo: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _continue() {
    final doc = AppStore.instance.documentFor('photo');
    if (doc?.filePath == null) {
      setState(() => _error = 'Please take a profile photo to continue');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrationKycScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final doc = AppStore.instance.documentFor('photo');
        final hasPhoto = doc?.filePath != null;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(icon: const Icon(Icons.arrow_back, size: 22), onPressed: () => Navigator.maybePop(context)),
            title: Text('Profile Photo', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const OnboardingStepIndicator(step: 4),
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: _capture,
                      child: Opacity(
                        opacity: _acknowledged || hasPhoto ? 1.0 : 0.45,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.inputBg,
                            border: Border.all(color: hasPhoto ? AppColors.success : AppColors.border, width: 2),
                          ),
                          child: ClipOval(
                            child: _uploading
                                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                                : hasPhoto
                                    ? _previewImage(doc!.filePath!)
                                    : Icon(Icons.person_outline_rounded, size: 64, color: AppColors.textTertiary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      hasPhoto ? 'Tap to retake' : 'Tap to take a selfie',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Requirements', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ..._requirements.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.primaryDark),
                            const SizedBox(width: 10),
                            Text(r, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => _acknowledged = !_acknowledged),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _acknowledged,
                          activeColor: AppColors.primary,
                          onChanged: (v) => setState(() => _acknowledged = v ?? false),
                        ),
                        Expanded(
                          child: Text(
                            'I confirm this photo meets the above requirements',
                            style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(_error!, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.red.shade700)),
                  ],
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: hasPhoto ? _continue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.black,
                        disabledBackgroundColor: AppColors.border,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Continue', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _previewImage(String path) {
    if (path.startsWith('http')) return Image.network(path, fit: BoxFit.cover, width: 150, height: 150);
    return Image.file(File(path), fit: BoxFit.cover, width: 150, height: 150);
  }
}
