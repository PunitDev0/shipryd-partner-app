import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:partner/features/ride/domain/ride_controller.dart';
import 'package:partner/features/ride/presentation/ride_completed_screen.dart';
import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/utils/formatters.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> _openMaps(String address) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class RideDetailsScreen extends StatefulWidget {
  static const route = '/ride-details';
  final String rideId;
  const RideDetailsScreen({super.key, required this.rideId});

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final _otpController = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _codCashCollected = false;
  String? _payuQrString;
  bool _loadingQr = false;
  String? _qrError;

  Future<void> _loadPayUQr() async {
    final ride = RideController.findById(widget.rideId);
    if (ride == null || ride.codAmount <= 0) return;
    if (_payuQrString != null || _loadingQr) return;

    setState(() {
      _loadingQr = true;
      _qrError = null;
    });

    try {
      final res = await OrderStore.instance.initiatePayment(
        amount: ride.codAmount,
        bookingId: ride.id,
      );
      if (mounted) {
        setState(() {
          _payuQrString = res['qrString'] as String?;
          _loadingQr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _qrError = e.toString().replaceAll('Exception: ', '');
          _loadingQr = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    RideController.markViewed(widget.rideId);
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndStartTrip() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      setState(() => _error = 'Please enter a valid 4-digit OTP');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await RideController.startTrip(widget.rideId, otp: otp);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip started! Drive safely.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _completeRide() async {
    final ride = RideController.findById(widget.rideId);
    if (ride == null) return;

    final isAlreadyPaid = ride.paymentStatus == 'paid';
    if (ride.paymentMode == 'COD' && !isAlreadyPaid && !_codCashCollected) {
      setState(() => _error = 'Please confirm cash payment collection first or verify online payment');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await RideController.completeRide(widget.rideId);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RideCompletedScreen(rideId: widget.rideId),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel this ride?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          'This will return the passenger back to the search queue. Are you sure you want to cancel?',
          style: GoogleFonts.inter(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Ride', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cancel Ride',
              style: GoogleFonts.inter(color: const Color(0xFFE53935), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await RideController.cancel(widget.rideId);
      if (context.mounted) Navigator.maybePop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel ride: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: RideController.listenable,
      builder: (context, _) {
        final ride = RideController.findById(widget.rideId);
        if (ride == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                'Ride details not found',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        if (ride.status == OrderStatus.pickedUp && ride.paymentMode == 'COD' && _payuQrString == null && !_loadingQr && _qrError == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadPayUQr());
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'Ride Details',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            actions: [
              if (ride.status == OrderStatus.pending || ride.status == OrderStatus.pickedUp)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Color(0xFFE53935)),
                  onPressed: () => _confirmCancel(context),
                )
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // 1. Mock Map Route Visualizer
                Container(
                  height: 180,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _RouteMapPainter(
                              inProgress: ride.status == OrderStatus.pickedUp,
                            ),
                          ),
                        ),
                        // Floating indicators
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.navigation_rounded, color: AppColors.primary, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '${ride.distanceKm.toStringAsFixed(1)} km',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _statusBadge(ride.status),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Main Details
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Passenger Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primaryLight,
                                child: const Icon(Icons.person, color: AppColors.primaryDark, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ride.fromName,
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 14),
                                        const SizedBox(width: 3),
                                        Text(
                                          '4.8 · Passenger',
                                          style: GoogleFonts.inter(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Call Button
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFF0FDF4),
                                  foregroundColor: const Color(0xFF16A34A),
                                  padding: const EdgeInsets.all(10),
                                ),
                                icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
                                onPressed: () => launchUrl(Uri.parse('tel:9999999999')),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Route Details (Pickup -> Drop)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _routeStep(
                                title: 'PICKUP',
                                address: ride.fromAddress,
                                isPickup: true,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                                child: Container(
                                  width: 1.5,
                                  height: 24,
                                  color: AppColors.border,
                                ),
                              ),
                              _routeStep(
                                title: 'DROP-OFF',
                                address: ride.toAddress,
                                isPickup: false,
                              ),
                            ],
                          ),
                        ),

                        // Live Map Navigation Buttons
                        if (ride.status == OrderStatus.pending || ride.status == OrderStatus.pickedUp) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _mapNavButton(
                                  label: 'Map to Pickup',
                                  icon: Icons.directions_rounded,
                                  address: ride.fromAddress,
                                  active: ride.status == OrderStatus.pending,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _mapNavButton(
                                  label: 'Map to Drop',
                                  icon: Icons.flag_rounded,
                                  address: ride.toAddress,
                                  active: ride.status == OrderStatus.pickedUp,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Earning Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Earnings',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    ride.paymentMode == 'COD' ? 'COD cash collection' : 'Prepaid (Wallet)',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: ride.paymentMode == 'COD' ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                formatAmount(ride.earning),
                                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),

                        // Inline Error
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],

                        // OTP Section (Only when Pending)
                        if (ride.status == OrderStatus.pending) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Ask passenger for Start OTP',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 10,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0000',
                                    counterText: '',
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _saving ? null : _verifyAndStartTrip,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: _saving
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(
                                            'Verify & Start Ride',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // COD cash collection checklist (When PickedUp and payment mode is COD)
                        if (ride.status == OrderStatus.pickedUp && ride.paymentMode == 'COD') ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9E6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.monetization_on_rounded, color: Color(0xFFD97706), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Collect Payment',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Fare Amount to Collect:',
                                  style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formatAmount(ride.codAmount),
                                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 16),
                                if (ride.paymentStatus == 'paid') ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Online Payment Received Successfully!',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF1B5E20),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    'Option 1: Scan UPI QR to Pay Online',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: _loadingQr
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 24),
                                            child: CircularProgressIndicator(color: AppColors.primary),
                                          )
                                        : _qrError != null
                                            ? Text(
                                                'Failed to load QR code: $_qrError',
                                                style: GoogleFonts.inter(color: Colors.red, fontSize: 12),
                                              )
                                            : _payuQrString != null
                                                ? Column(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(12),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(16),
                                                          border: Border.all(color: Colors.grey.shade300),
                                                        ),
                                                        child: QrImageView(
                                                          data: _payuQrString!,
                                                          version: QrVersions.auto,
                                                          size: 160.0,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        'Scan using GPay, PhonePe, Paytm, etc.',
                                                        style: GoogleFonts.inter(
                                                          color: AppColors.textSecondary,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : const SizedBox(),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(child: Divider()),
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8),
                                          child: Text('OR', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        ),
                                        Expanded(child: Divider()),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Option 2: Pay via Physical Cash',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _codCashCollected,
                                        activeColor: AppColors.primary,
                                        checkColor: Colors.black,
                                        onChanged: (val) {
                                          setState(() {
                                            _codCashCollected = val ?? false;
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Confirm cash payment received',
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (ride.paymentStatus != 'paid') ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () async {
                                          setState(() => _loadingQr = true);
                                          try {
                                            await OrderStore.instance.refresh();
                                          } catch (e) {
                                            // ignore
                                          } finally {
                                            if (mounted) {
                                              setState(() => _loadingQr = false);
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: Text(
                                          'Verify Online Payment',
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.blue.shade700,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Completed Detail Info
                        if (ride.status == OrderStatus.received) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ride Completed on ${formatDateTime(ride.receivedAt ?? DateTime.now())}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF166534)),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 3. Persistent Bottom Button (When PickedUp)
                if (ride.status == OrderStatus.pickedUp)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _completeRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF34C759),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'End Ride & Complete',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _routeStep({required String title, required String address, required bool isPickup}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isPickup ? Icons.circle : Icons.location_on_rounded,
          size: 20,
          color: isPickup ? AppColors.primaryDark : const Color(0xFFE53935),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(OrderStatus status) {
    late final String label;
    late final Color bg;
    late final Color fg;
    switch (status) {
      case OrderStatus.requested:
      case OrderStatus.pending:
        label = 'Pending Start';
        bg = AppColors.primary;
        fg = AppColors.black;
        break;
      case OrderStatus.pickedUp:
        label = 'Ongoing Trip';
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case OrderStatus.received:
        label = 'Completed';
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case OrderStatus.canceled:
        label = 'Canceled';
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _mapNavButton({required String label, required IconData icon, required String address, required bool active}) {
    if (active) {
      return ElevatedButton.icon(
        onPressed: () => _openMaps(address),
        icon: Icon(icon, size: 16, color: AppColors.black),
        label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: () => _openMaps(address),
        icon: Icon(icon, size: 16, color: AppColors.textSecondary),
        label: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

class _RouteMapPainter extends CustomPainter {
  final bool inProgress;
  const _RouteMapPainter({required this.inProgress});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw grid background
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const double step = 20.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += step) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    // 2. Draw route path
    final path = Path()
      ..moveTo(40, size.height - 40)
      ..cubicTo(
        size.width * 0.3, size.height - 40,
        size.width * 0.4, 40,
        size.width - 40, 40,
      );

    final routeBorderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final routePaint = Paint()
      ..color = inProgress ? const Color(0xFF0EA5E9) : AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, routeBorderPaint);
    canvas.drawPath(path, routePaint);

    // 3. Draw dotted segments to show path texture
    final dottedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, dottedPaint);

    // 4. Draw Start Pin
    final startOffset = Offset(40, size.height - 40);
    _drawPin(canvas, startOffset, AppColors.primaryDark, 'P');

    // 5. Draw End Pin
    final endOffset = Offset(size.width - 40, 40);
    _drawPin(canvas, endOffset, const Color(0xFFE53935), 'D');

    // 6. Draw rider position indicator along the route
    final indicatorOffset = inProgress
        ? Offset(size.width * 0.65, size.height * 0.4)
        : Offset(40, size.height - 40);

    final pulsePaint = Paint()
      ..color = (inProgress ? const Color(0xFF0EA5E9) : AppColors.primary).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(indicatorOffset, 16.0, pulsePaint);

    final bikeIconBgPaint = Paint()
      ..color = inProgress ? const Color(0xFF0284C7) : AppColors.primaryDark
      ..style = PaintingStyle.fill;
    canvas.drawCircle(indicatorOffset, 8.0, bikeIconBgPaint);

    final bikePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(indicatorOffset, 3.0, bikePaint);
  }

  void _drawPin(Canvas canvas, Offset offset, Color color, String text) {
    // shadow
    canvas.drawCircle(offset + const Offset(0, 2), 10.0, Paint()..color = Colors.black.withValues(alpha: 0.4));

    // pin outer
    final pinPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, 10.0, pinPaint);

    // pin inner white
    canvas.drawCircle(offset, 8.0, Paint()..color = Colors.white);

    // dot center
    canvas.drawCircle(offset, 4.0, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.inProgress != inProgress;
}
