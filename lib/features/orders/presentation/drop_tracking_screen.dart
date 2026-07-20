import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart' show LatLng;
import 'package:geolocator/geolocator.dart';
import 'package:partner/features/orders/presentation/booking_chat_screen.dart';
import 'package:partner/features/orders/presentation/navigation_screen.dart';
import 'package:partner/shared/models/order.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/utils/formatters.dart';
import 'package:partner/shared/widgets/swipe_to_confirm_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Drop-off leg screen — customer/order card, distance-to-drop, Hold to
/// Complete → payments → summary. Same as [PickupTrackingScreen], this has
/// NO embedded map/Navigation SDK code: "Go to drop" pushes the shared,
/// reusable [NavigationScreen] full-screen and waits for real arrival.
class DropTrackingScreen extends StatefulWidget {
  final String orderId;
  final bool initialShowPayments;
  const DropTrackingScreen({super.key, required this.orderId, this.initialShowPayments = false});

  @override
  State<DropTrackingScreen> createState() => _DropTrackingScreenState();
}

class _DropTrackingScreenState extends State<DropTrackingScreen> {
  double? _distanceMeters;
  bool _locationDenied = false;

  late bool _showPaymentsScreen = widget.initialShowPayments;
  bool _qrGenerated = false;
  bool _loadingQr = false;
  String? _payuQrString;
  bool _savingPayment = false;

  bool _showSummaryScreen = false;

  int _customerRating = 5;
  final Set<String> _selectedCustomerTags = {};
  final TextEditingController _customerFeedbackController = TextEditingController();
  final List<String> _customerTagOptions = const ['Polite Customer', 'On Time', 'Easy Location', 'Friendly'];

  @override
  void dispose() {
    _customerFeedbackController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refreshDistance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OrderStore.instance.refresh();
    });
  }

  /// Lightweight, one-shot straight-line distance to drop — no map, no
  /// Navigation SDK session here; that only spins up inside
  /// [NavigationScreen] once the partner taps "Go to drop".
  Future<void> _refreshDistance() async {
    try {
      final order = OrderStore.instance.findById(widget.orderId);
      if (order == null) return;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationDenied = true);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationDenied = true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6)),
      );
      if (!mounted) return;
      setState(() {
        _distanceMeters = Geolocator.distanceBetween(
          position.latitude, position.longitude,
          order.dropLat, order.dropLng,
        );
        _locationDenied = false;
      });
    } catch (e) {
      debugPrint('Distance fetch failed: $e');
      if (mounted) setState(() => _locationDenied = true);
    }
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '—';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '${meters.round()} m';
  }

  Future<void> _goToDropNavigation(Order order) async {
    final reached = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          destination: LatLng(latitude: order.dropLat, longitude: order.dropLng),
          destinationTitle: 'Drop-off',
          orderId: order.id,
          peerName: order.fromName,
        ),
      ),
    );
    if (reached == true) {
      _refreshDistance();
    }
  }

  Future<void> _generatePayUQr(Order order) async {
    setState(() => _loadingQr = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() {
      _qrGenerated = true;
      _loadingQr = false;
      _payuQrString = "upi://pay?pa=shipryd@payu&pn=ShipRyd&am=${order.codAmount}&cu=INR";
    });
  }

  Future<void> _confirmCashPayment(Order order) async {
    setState(() => _savingPayment = true);
    try {
      await OrderStore.instance.completeOrder(order.id);
      setState(() => _showSummaryScreen = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to settle payment: $e')));
    } finally {
      setState(() => _savingPayment = false);
    }
  }

  void _showOrderActionsSheet(Order order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161A22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order Management', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildActionItem(
                  icon: Icons.phone_forwarded_rounded,
                  title: 'Contact Customer',
                  color: Colors.greenAccent,
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse('tel:${order.fromName}'));
                  },
                ),
                _buildActionItem(
                  icon: Icons.cancel_outlined,
                  title: 'Cancel My Order',
                  color: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF161A22),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Cancel Order?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                        content: Text('Are you sure you want to cancel this booking?', style: GoogleFonts.outfit(color: Colors.white70)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('No', style: GoogleFonts.outfit(color: const Color(0x8CFFFFFF)))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Cancel Ride', style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await OrderStore.instance.cancelOrder(order.id);
                      if (mounted) Navigator.pop(context);
                    }
                  },
                ),
                _buildActionItem(
                  icon: Icons.shield_outlined,
                  title: 'Call Police (SOS)',
                  color: Colors.orangeAccent,
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse('tel:112'));
                  },
                ),
                _buildActionItem(
                  icon: Icons.help_center_outlined,
                  title: 'Get Help',
                  color: Colors.cyanAccent,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support line is active. We are here to help.')));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionItem({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E2430), borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kBg = AppColors.background;
    final kCardBg = AppColors.cardBg;
    final kCyan = AppColors.primary;
    final kText = AppColors.textPrimary;
    final kMuted = AppColors.textSecondary;

    return Scaffold(
      backgroundColor: kBg,
      body: AnimatedBuilder(
        animation: OrderStore.instance,
        builder: (context, _) {
          final order = OrderStore.instance.findById(widget.orderId);
          if (order == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_showSummaryScreen) {
            return _buildSummaryScreen(order);
          }
          if (_showPaymentsScreen) {
            return _buildPaymentsScreen(order);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: kCardBg, shape: BoxShape.circle),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: kText, size: 18),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showOrderActionsSheet(order),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              Icon(Icons.phone_in_talk_rounded, color: kCyan, size: 18),
                              const SizedBox(width: 6),
                              Text('Actions', style: GoogleFonts.outfit(color: kText, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Icon(order is ParcelOrder ? Icons.local_shipping_rounded : Icons.flag_rounded, color: kCyan, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    order is ParcelOrder ? 'Delivering Parcel' : 'Active Ride',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: kText),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _locationDenied ? 'Enable location to see distance' : '${_formatDistance(_distanceMeters)} away',
                    style: GoogleFonts.outfit(fontSize: 14, color: kMuted, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(16)),
                    child: Builder(
                      builder: (context) {
                        final parcel = order is ParcelOrder ? order : null;
                        final recipientName = parcel?.recipientName ?? order.fromName;
                        final recipientPhone = parcel?.recipientPhone ?? '+91 98765 43210';

                        return Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(color: Color(0xFF1E2430), shape: BoxShape.circle),
                              child: Icon(order is ParcelOrder ? Icons.inventory_2_rounded : Icons.person_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recipientName,
                                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: kText),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    order.toAddress,
                                    style: GoogleFonts.outfit(fontSize: 11.5, color: kMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse('tel:$recipientPhone');
                                if (await canLaunchUrl(uri)) await launchUrl(uri);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(color: Color(0xFF1E2430), shape: BoxShape.circle),
                                child: const Icon(Icons.phone_rounded, color: Color(0xFF34C759), size: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingChatScreen(bookingId: order.id, peerName: recipientName))),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(color: Color(0xFF1E2430), shape: BoxShape.circle),
                                child: Icon(Icons.chat_bubble_outline_rounded, color: kCyan, size: 18),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const Spacer(),

                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: GestureDetector(
                          onTap: () => _goToDropNavigation(order),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: kCyan,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: kCyan.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.navigation_rounded, color: Color(0xFF090A0F), size: 18),
                                const SizedBox(width: 6),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Go to drop',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF090A0F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: SwipeToConfirmButton(
                          text: 'Swipe to Complete',
                          onConfirmed: () => setState(() => _showPaymentsScreen = true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentsScreen(Order order) {
    final isDark = AppStore.instance.darkMode;
    final kBg = isDark ? const Color(0xFF090A0F) : Colors.white;
    final kCardBg = isDark ? const Color(0xFF161822) : const Color(0xFFF7F8FA);
    final kCyan = AppColors.primary;
    final textPrimary = isDark ? Colors.white : const Color(0xFF090A0F);
    final textSecondary = isDark ? const Color(0xFF9E9EA5) : const Color(0xFF555555);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => setState(() => _showPaymentsScreen = false),
        ),
        title: Text('Payments', style: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          TextButton(onPressed: () {}, child: Text('Help', style: GoogleFonts.outfit(color: kCyan, fontWeight: FontWeight.bold))),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(child: Text('Estimated Order Fare', style: GoogleFonts.outfit(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w600))),
              const SizedBox(height: 8),
              Center(child: Text(formatAmount(order.codAmount), style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w900, color: const Color(0xFF2E7D32)))),
              const SizedBox(height: 36),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Online QR Payment', style: GoogleFonts.outfit(fontSize: 14.5, color: textPrimary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Scan & Pay instantly using any UPI app', style: GoogleFonts.outfit(fontSize: 11.5, color: textSecondary)),
                      const SizedBox(height: 24),
                      if (!_qrGenerated)
                        GestureDetector(
                          onTap: () => _generatePayUQr(order),
                          child: Container(
                            height: 160,
                            width: 160,
                            decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: kCyan.withValues(alpha: 0.3))),
                            child: Center(
                              child: _loadingQr
                                  ? const CircularProgressIndicator()
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.qr_code_2_rounded, color: kCyan, size: 48),
                                        const SizedBox(height: 8),
                                        Text('Generate QR Code', style: GoogleFonts.outfit(color: kCyan, fontWeight: FontWeight.bold, fontSize: 12.5)),
                                      ],
                                    ),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 160,
                          width: 160,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                          child: Image.network(
                            'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${Uri.encodeComponent(_payuQrString ?? "")}',
                            fit: BoxFit.contain,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _savingPayment ? null : () => _confirmCashPayment(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCyan,
                  foregroundColor: const Color(0xFF090A0F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _savingPayment
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                    : Text('Collect Cash', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryScreen(Order order) {
    final isDark = AppStore.instance.darkMode;
    final kBg = isDark ? const Color(0xFF090A0F) : Colors.white;
    final kCardBg = isDark ? const Color(0xFF161822) : const Color(0xFFF7F8FA);
    final kCyan = AppColors.primary;
    final textPrimary = isDark ? Colors.white : const Color(0xFF090A0F);
    final textSecondary = isDark ? const Color(0xFF9E9EA5) : const Color(0xFF4A4A4A);
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: Text('Order Completed!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary))),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Trip earnings have been settled in your wallet.',
                  style: GoogleFonts.outfit(fontSize: 13.5, color: textSecondary, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: dividerColor),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Order ID', order.orderId, isValueBold: true, textPrimary: textPrimary, textSecondary: textSecondary),
                    Divider(color: dividerColor, height: 24),
                    _buildSummaryRow('Distance Travelled', '${order.distanceKm.toStringAsFixed(1)} KM', textPrimary: textPrimary, textSecondary: textSecondary),
                    Divider(color: dividerColor, height: 24),
                    _buildSummaryRow('Customer Fare Paid', formatAmount(order.codAmount), textPrimary: textPrimary, textSecondary: textSecondary),
                    Divider(color: dividerColor, height: 24),
                    _buildSummaryRow('Your Earnings', formatAmount(order.earning), colorValue: const Color(0xFF2E7D32), isValueBold: true, textPrimary: textPrimary, textSecondary: textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rate Customer (${order.fromName})', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('How was your experience with the customer?', style: GoogleFonts.outfit(fontSize: 12, color: textSecondary)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        return GestureDetector(
                          onTap: () => setState(() => _customerRating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              i < _customerRating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: i < _customerRating ? AppColors.primary : textSecondary,
                              size: 36,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _customerTagOptions.map((tag) {
                        final isSelected = _selectedCustomerTags.contains(tag);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCustomerTags.remove(tag);
                              } else {
                                _selectedCustomerTags.add(tag);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? AppColors.primary : dividerColor),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF090A0F) : textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customerFeedbackController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Write feedback for customer (optional)...',
                        hintStyle: GoogleFonts.outfit(color: textSecondary, fontSize: 12.5),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF222430) : const Color(0xFFEEEEEE),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: GoogleFonts.outfit(fontSize: 13, color: textPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kCyan,
                  foregroundColor: const Color(0xFF090A0F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Submit Review & Back to Dashboard', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? colorValue, bool isValueBold = false, required Color textPrimary, required Color textSecondary}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(color: textSecondary, fontSize: 13.5, fontWeight: FontWeight.w600)),
        Text(
          value,
          style: GoogleFonts.outfit(color: colorValue ?? textPrimary, fontWeight: isValueBold ? FontWeight.bold : FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }
}
