import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import 'confirm_receive_screen.dart';
import 'add_proof_screen.dart';

Future<void> _openMaps(String address) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address)}',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class ParcelDetailsScreen extends StatefulWidget {
  static const route = '/parcel-details';
  final String parcelId;
  const ParcelDetailsScreen({super.key, required this.parcelId});

  @override
  State<ParcelDetailsScreen> createState() => _ParcelDetailsScreenState();
}

class _ParcelDetailsScreenState extends State<ParcelDetailsScreen> {
  @override
  void initState() {
    super.initState();
    AppStore.instance.markViewed(widget.parcelId);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final parcel = AppStore.instance.findParcelById(widget.parcelId);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'Parcel Details',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: parcel == null
              ? Center(
                  child: Text(
                    'Parcel not found',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                )
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                        const SizedBox(height: 8),
                        _StatusBadge(status: parcel.status),
                        const SizedBox(height: 20),

                        Text(
                          parcel.id,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order ID: ${parcel.orderId}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 28),

                        _DetailField(
                          label: 'From',
                          value: parcel.fromName,
                          subValue: parcel.fromAddress,
                        ),
                        const SizedBox(height: 20),
                        _DetailField(label: 'To', value: parcel.toAddress),

                        if (parcel.status != ParcelStatus.received &&
                            parcel.status != ParcelStatus.canceled) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildNavButton(
                                  label: 'Navigate to Pickup',
                                  icon: Icons.directions_rounded,
                                  address: parcel.fromAddress,
                                  isActive: parcel.status == ParcelStatus.pending,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildNavButton(
                                  label: 'Navigate to Drop',
                                  icon: Icons.flag_rounded,
                                  address: parcel.toAddress,
                                  isActive: parcel.status == ParcelStatus.pickedUp,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _DetailField(
                                label: 'Distance',
                                value: '${parcel.distanceKm.toStringAsFixed(1)} km',
                              ),
                            ),
                            Expanded(
                              child: _DetailField(
                                label: 'Est. Time',
                                value: '${parcel.etaMinutes} min',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: _DetailField(
                                label: parcel.orderType == OrderType.ride ? 'Ride Type' : 'Item Type',
                                value: parcel.itemType,
                              ),
                            ),
                            if (parcel.orderType != OrderType.ride)
                              Expanded(
                                child: _DetailField(
                                  label: 'Weight',
                                  value: '${parcel.weightKg} kg',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _DetailField(
                                label: 'Payment Mode',
                                value: parcel.paymentMode,
                              ),
                            ),
                            Expanded(
                              child: _DetailField(
                                label: 'Amount',
                                value: formatAmount(parcel.codAmount),
                              ),
                            ),
                          ],
                        ),

                        if (parcel.status != ParcelStatus.received && parcel.status != ParcelStatus.canceled) ...[
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryDark, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'You will earn',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ),
                                Text(
                                  formatAmount(parcel.earning),
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (parcel.status == ParcelStatus.received) ...[
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDFAF0),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Received on ${formatDateTime(parcel.receivedAt!)} · Earned ${formatAmount(parcel.earning)}',
                                    style: GoogleFonts.inter(fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (parcel.status == ParcelStatus.pending) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConfirmReceiveScreen(
                                    parcelId: parcel.id,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Confirm Receive',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ] else if (parcel.status == ParcelStatus.pickedUp) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddProofScreen(
                                    parcelId: parcel.id,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF34C759),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Deliver Parcel',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],

                        if (parcel.status == ParcelStatus.pending || parcel.status == ParcelStatus.pickedUp) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => _confirmCancel(context, parcel.id),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE53935),
                                side: const BorderSide(color: Color(0xFFE53935), width: 1.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Cancel Order',
                                style: GoogleFonts.inter(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _confirmCancel(BuildContext context, String parcelId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel this order?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text(
          'The order will go back to the customer\'s search queue for another partner. This can\'t be undone.',
          style: GoogleFonts.inter(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Order', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Order', style: GoogleFonts.inter(color: const Color(0xFFE53935), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AppStore.instance.cancelParcel(parcelId);
      if (context.mounted) Navigator.maybePop(context);
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel order: $e')),
        );
      }
    }
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required String address,
    required bool isActive,
  }) {
    if (isActive) {
      return ElevatedButton.icon(
        onPressed: () => _openMaps(address),
        icon: Icon(icon, size: 18, color: AppColors.black),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.black,
          elevation: 2,
          shadowColor: AppColors.primary.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primaryDark, width: 1.5),
          ),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: () => _openMaps(address),
        icon: Icon(icon, size: 18, color: AppColors.textSecondary),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final ParcelStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String label;
    switch (status) {
      case ParcelStatus.requested:
      case ParcelStatus.pending:
        bg = AppColors.primary;
        fg = AppColors.black;
        icon = Icons.verified_rounded;
        label = 'Valid Parcel';
        break;
      case ParcelStatus.pickedUp:
        bg = AppColors.primary;
        fg = AppColors.black;
        icon = Icons.local_shipping_rounded;
        label = 'In Transit';
        break;
      case ParcelStatus.received:
        bg = AppColors.success.withOpacity(0.12);
        fg = AppColors.success;
        icon = Icons.check_circle_rounded;
        label = 'Received';
        break;
      case ParcelStatus.canceled:
        bg = const Color(0xFFFDECEA);
        fg = const Color(0xFFE53935);
        icon = Icons.cancel_rounded;
        label = 'Canceled';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  final String? subValue;

  const _DetailField({
    required this.label,
    required this.value,
    this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        if (subValue != null) ...[
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13.5),
          ),
          Text(
            subValue!,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ] else
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
