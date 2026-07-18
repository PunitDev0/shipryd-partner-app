import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';

/// Shared document/photo capture tile used across the onboarding KYC steps
/// (profile photo, Aadhaar/PAN, driving licence, RC/insurance/pollution) —
/// generalizes the `_DocumentTile` pattern from the old generic documents
/// screen, but drives the real S3 upload flow (see
/// `PartnerService.uploadDocumentFile`) instead of a fake local path.
class KycCaptureTile extends StatefulWidget {
  final String label;
  final String? filePath;
  final DocumentStatus status;
  final Future<void> Function(File file) onCaptured;
  final bool cameraOnly;

  const KycCaptureTile({
    super.key,
    required this.label,
    required this.filePath,
    required this.status,
    required this.onCaptured,
    this.cameraOnly = false,
  });

  @override
  State<KycCaptureTile> createState() => _KycCaptureTileState();
}

class _KycCaptureTileState extends State<KycCaptureTile> {
  bool _uploading = false;

  Future<void> _pick() async {
    if (_uploading) return;
    ImageSource? source = widget.cameraOnly ? ImageSource.camera : null;
    source ??= await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
      if (picked == null) return;
      setState(() => _uploading = true);
      await widget.onCaptured(File(picked.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.filePath != null;
    return InkWell(
      onTap: _pick,
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
                  ? _preview(widget.filePath!)
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
                  Text(widget.label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_statusLabel(widget.status), style: GoogleFonts.inter(fontSize: 12, color: _statusColor(widget.status))),
                ],
              ),
            ),
            if (_uploading)
              const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
            else
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

  Widget _preview(String path) {
    // Remote (S3) URLs use Image.network; freshly-picked local files (before
    // the upload round-trip resolves) are still a device path.
    if (path.startsWith('http')) {
      return Image.network(path, width: 46, height: 46, fit: BoxFit.cover);
    }
    return Image.file(File(path), width: 46, height: 46, fit: BoxFit.cover);
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
