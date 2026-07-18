import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/app_store.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../screens/parcel_details_screen.dart';
import '../main.dart';

/// Full-screen "new order request" card that appears over whatever screen
/// the partner is currently on — mirrors the accept/reject flow on Porter
/// and other driver apps: a countdown ring, route + earning summary, and
/// Accept/Decline actions. Auto-declines (as a timeout) if left untouched.
class IncomingOrderOverlay extends StatefulWidget {
  final Parcel parcel;
  const IncomingOrderOverlay({super.key, required this.parcel});

  @override
  State<IncomingOrderOverlay> createState() => _IncomingOrderOverlayState();
}

class _IncomingOrderOverlayState extends State<IncomingOrderOverlay> {
  static const _totalSeconds = 15;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        _decline(timedOut: true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _decline({bool timedOut = false}) {
    if (_settled) return;
    _settled = true;
    AppStore.instance.declineOrderRequest(widget.parcel.id, timedOut: timedOut);
  }

  Future<void> _accept() async {
    if (_settled) return;
    _settled = true;
    HapticFeedback.lightImpact();
    // Cache the navigator state before we await and the overlay is unmounted
    final navigator = ShiprydPartnerApp.navigatorKey.currentState;
    try {
      await AppStore.instance.acceptOrderRequest(widget.parcel.id);
      navigator?.push(
        MaterialPageRoute(
          builder: (_) => ParcelDetailsScreen(parcelId: widget.parcel.id),
        ),
      );
    } catch (e) {
      AppStore.instance.declineOrderRequest(widget.parcel.id, timedOut: true);
      final context = ShiprydPartnerApp.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parcel;
    return Material(
      color: Colors.black.withOpacity(0.55),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.orderType == OrderType.ride ? 'NEW RIDE REQUEST' : 'NEW ORDER REQUEST',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _CountdownRing(secondsLeft: _secondsLeft, totalSeconds: _totalSeconds),
                  ],
                ),
                const SizedBox(height: 18),

                Text(
                  formatAmount(p.earning),
                  style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                Text(
                  'Estimated earning · ${p.distanceKm.toStringAsFixed(1)} km · ${p.etaMinutes} min',
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                _RouteRow(
                  icon: Icons.circle,
                  iconColor: AppColors.primaryDark,
                  iconSize: 10,
                  title: p.fromName,
                  subtitle: p.fromAddress,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Container(
                    width: 1.4,
                    height: 22,
                    color: AppColors.border,
                  ),
                ),
                _RouteRow(
                  icon: Icons.location_on_rounded,
                  iconColor: AppColors.textSecondary,
                  iconSize: 16,
                  title: 'Drop-off',
                  subtitle: p.toAddress,
                ),

                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(label: p.itemType),
                    if (p.orderType != OrderType.ride) _Chip(label: '${p.weightKg} kg'),
                    _Chip(
                      label: p.paymentMode == 'COD'
                          ? 'COD · ${formatAmount(p.codAmount)}'
                          : 'Prepaid',
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _decline,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE53935),
                            side: const BorderSide(color: Color(0xFFE53935), width: 1.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Decline',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _accept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Accept ($_secondsLeft s)',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  const _CountdownRing({required this.secondsLeft, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              value: secondsLeft / totalSeconds,
              strokeWidth: 3,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          Text(
            '$secondsLeft',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String title;
  final String subtitle;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}