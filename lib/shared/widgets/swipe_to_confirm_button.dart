import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact interactive Swipe-to-Confirm action button (Rapido / Uber style swipe slider).
class SwipeToConfirmButton extends StatefulWidget {
  final String text;
  final VoidCallback onConfirmed;
  final Color baseColor;

  const SwipeToConfirmButton({
    super.key,
    required this.text,
    required this.onConfirmed,
    this.baseColor = const Color(0xFFF2C230),
  });

  @override
  State<SwipeToConfirmButton> createState() => _SwipeToConfirmButtonState();
}

class _SwipeToConfirmButtonState extends State<SwipeToConfirmButton> with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _confirmed = false;
  late AnimationController _animController;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animController.addListener(() {
      setState(() {
        _dragPosition = _anim.value;
      });
    });
  }

  @override
  void didUpdateWidget(SwipeToConfirmButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      setState(() {
        _confirmed = false;
        _dragPosition = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details, double maxDrag) {
    if (_confirmed) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onPanEnd(DragEndDetails details, double maxDrag) {
    if (_confirmed) return;
    if (_dragPosition >= maxDrag * 0.65) {
      setState(() => _confirmed = true);
      widget.onConfirmed();

      _anim = Tween<double>(begin: _dragPosition, end: maxDrag).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      );
      _animController.forward(from: 0.0).then((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _confirmed = false;
              _dragPosition = 0.0;
            });
          }
        });
      });
    } else {
      _anim = Tween<double>(begin: _dragPosition, end: 0.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      );
      _animController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    const handleWidth = 42.0;
    const height = 52.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = (constraints.maxWidth - handleWidth - 4).clamp(0.0, double.infinity);
        final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF141824), // High contrast dark background
            border: Border.all(color: widget.baseColor.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.baseColor.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Progress fill behind handle
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _dragPosition + handleWidth / 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.baseColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // Non-overlapping centered text label
              Positioned.fill(
                left: handleWidth + 4,
                right: 6,
                child: Opacity(
                  opacity: (1.0 - (progress * 1.5)).clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.text,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.double_arrow_rounded,
                            color: widget.baseColor,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Draggable handle (Thumb)
              Positioned(
                left: _dragPosition + 2,
                top: 3,
                bottom: 3,
                child: GestureDetector(
                  onPanUpdate: (d) => _onPanUpdate(d, maxDrag),
                  onPanEnd: (d) => _onPanEnd(d, maxDrag),
                  child: Container(
                    width: handleWidth - 2,
                    decoration: BoxDecoration(
                      color: widget.baseColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _confirmed ? Icons.check_rounded : Icons.arrow_forward_rounded,
                        color: const Color(0xFF090A0F),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
