import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/models/models.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'registration_review_screen.dart';

/// KYC document upload step. Also reused (isOnboarding: false) as the
/// read-only "Documents" screen from the profile tab.
class RegistrationDocumentsScreen extends StatefulWidget {
  static const route = '/registration-documents';
  final bool isOnboarding;
  const RegistrationDocumentsScreen({super.key, this.isOnboarding = true});

  @override
  State<RegistrationDocumentsScreen> createState() =>
      _RegistrationDocumentsScreenState();
}

class _RegistrationDocumentsScreenState extends State<RegistrationDocumentsScreen> {
  Future<void> _pickFor(DocumentItem doc) async {
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
        picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
      } catch (_) {
        if (source == ImageSource.camera) {
          picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
        } else {
          rethrow;
        }
      }
      if (picked != null) {
        await AppStore.instance.setDocument(doc.key, picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access camera/gallery: $e')),
        );
      }
    }
  }

  void _continue() {
    if (!AppStore.instance.allDocumentsProvided) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all documents to continue')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegistrationReviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final docs = AppStore.instance.documents;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              widget.isOnboarding ? 'Upload Documents' : 'Documents',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isOnboarding) ...[
                    const SizedBox(height: 4),
                    _StepIndicator(step: 3, total: 4),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _DocumentTile(
                        doc: docs[i],
                        onTap: () => _pickFor(docs[i]),
                      ),
                    ),
                  ),
                  if (widget.isOnboarding) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _continue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('Continue', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final DocumentItem doc;
  final VoidCallback onTap;
  const _DocumentTile({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasFile = doc.filePath != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasFile
                  ? Image.file(File(doc.filePath!), width: 46, height: 46, fit: BoxFit.cover)
                  : Container(
                      width: 46,
                      height: 46,
                      color: AppColors.primaryLight,
                      child: const Icon(Icons.description_outlined, color: AppColors.primaryDark),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_statusLabel(doc.status), style: GoogleFonts.inter(fontSize: 12, color: _statusColor(doc.status))),
                ],
              ),
            ),
            Icon(
              hasFile ? Icons.check_circle_rounded : Icons.upload_rounded,
              size: 20,
              color: hasFile ? AppColors.success : AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(DocumentStatus s) => switch (s) {
        DocumentStatus.missing => 'Tap to upload',
        DocumentStatus.pending => 'Uploaded · Pending verification',
        DocumentStatus.verified => 'Submitted',
      };

  Color _statusColor(DocumentStatus s) => switch (s) {
        DocumentStatus.missing => AppColors.textSecondary,
        DocumentStatus.pending => AppColors.primaryDark,
        DocumentStatus.verified => AppColors.success,
      };
}

class _StepIndicator extends StatelessWidget {
  final int step;
  final int total;
  const _StepIndicator({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Step $step of $total',
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: step / total,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
