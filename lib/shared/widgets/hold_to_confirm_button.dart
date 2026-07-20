import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Progressive hold-to-confirm action button (1.2s hold) — used instead of
/// a plain tap button for irreversible actions (mark arrived, complete
/// delivery) so they can't be triggered by an accidental tap.
class HoldToConfirmButton extends StatefulWidget {
  final String text;
  final VoidCallback onConfirmed;
  final Color baseColor;

  const HoldToConfirmButton({
    super.key,
    required this.text,
    required this.onConfirmed,
    this.baseColor = const Color(0xFFF2C230),
  });

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onConfirmed();
        _progressController.reset();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _progressController.forward(),
      onTapUp: (_) {
        if (_progressController.status != AnimationStatus.completed) {
          _progressController.reverse();
        }
      },
      onTapCancel: () {
        if (_progressController.status != AnimationStatus.completed) {
          _progressController.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          return Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  widget.baseColor,
                  widget.baseColor.withValues(alpha: 0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.baseColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Hold indicator progress bar fill
                Positioned(
                  top: 0, bottom: 0, left: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.45 * _progressController.value,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    widget.text,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF090A0F),
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
