import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:partner/features/orders/presentation/incoming_parcels_screen.dart';
import 'package:partner/features/profile/presentation/profile_screen.dart';
import 'package:partner/features/notifications/presentation/notifications_screen.dart';
import 'package:partner/features/wallet/presentation/earnings_screen.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/utils/formatters.dart';
import 'package:partner/shared/widgets/bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  static const route = '/dashboard';
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  gmaps.GoogleMapController? _mapController;
  Set<gmaps.Marker> _markers = {};
  Set<gmaps.Circle> _circles = {};
  bool _mapLoading = true;
  bool _isBuildingMarkers = false;
  gmaps.BitmapDescriptor? _cachedDriverDot;
  final Map<String, gmaps.BitmapDescriptor> _demandMarkerCache = {};

  @override
  void initState() {
    super.initState();
    OrderStore.instance.addListener(_onOrderStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDemandData();
    });
  }

  @override
  void dispose() {
    OrderStore.instance.removeListener(_onOrderStoreChanged);
    super.dispose();
  }

  void _onOrderStoreChanged() {
    _updateMarkersAndCircles();
  }

  Future<void> _refreshDemandData() async {
    await OrderStore.instance.fetchDemandHeatmap();
  }

  Future<void> _updateMarkersAndCircles() async {
    if (_isBuildingMarkers) return;
    _isBuildingMarkers = true;

    try {
      final driverDot = await _createDriverDotMarker();
      final Set<gmaps.Marker> newMarkers = {
        gmaps.Marker(
          markerId: const gmaps.MarkerId('driver_loc'),
          position: const gmaps.LatLng(28.4595, 77.0726),
          icon: driverDot,
          anchor: const Offset(0.5, 0.5),
        ),
      };

      final Set<gmaps.Circle> newCircles = {
        gmaps.Circle(
          circleId: const gmaps.CircleId('driver_pulse'),
          center: const gmaps.LatLng(28.4595, 77.0726),
          radius: 200,
          fillColor: Colors.blue.withValues(alpha: 0.08),
          strokeColor: Colors.blue.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
      };

      final sectors = OrderStore.instance.demandSectors;
      if (sectors.isEmpty) {
        if (mounted) {
          setState(() {
            _markers = newMarkers;
            _circles = newCircles;
            _mapLoading = false;
          });
        }
        _isBuildingMarkers = false;
        return;
      }

      for (final sector in sectors) {
        final String id = sector['id'] ?? '';
        final String title = sector['title'] ?? '';
        final String subtitle = sector['subtitle'] ?? '';
        final String surge = sector['surge'] ?? '1.0x';
        final double lat = (sector['lat'] as num?)?.toDouble() ?? 0.0;
        final double lng = (sector['lng'] as num?)?.toDouble() ?? 0.0;
        final String colorHex = sector['colorHex'] ?? '#FBC02D';

        Color sectorColor = Colors.amber;
        try {
          final hex = colorHex.replaceAll('#', '');
          sectorColor = Color(int.parse('FF$hex', radix: 16));
        } catch (_) {}

        final markerIcon = await _createDemandMarker(
          surge: surge,
          title: title,
          subtitle: subtitle,
          color: sectorColor,
        );

        newMarkers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(id),
            position: gmaps.LatLng(lat, lng),
            icon: markerIcon,
            anchor: const Offset(0.5, 0.5),
          ),
        );

        newCircles.add(
          gmaps.Circle(
            circleId: gmaps.CircleId('${id}_circle'),
            center: gmaps.LatLng(lat, lng),
            radius: 600,
            fillColor: sectorColor.withValues(alpha: 0.12),
            strokeColor: sectorColor.withValues(alpha: 0.25),
            strokeWidth: 1,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
          _circles = newCircles;
          _mapLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error updating markers: $e');
    } finally {
      _isBuildingMarkers = false;
    }
  }

  Future<gmaps.BitmapDescriptor> _createDriverDotMarker() async {
    if (_cachedDriverDot != null) return _cachedDriverDot!;
    final double scale = MediaQuery.of(context).devicePixelRatio;
    final size = (24 * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    canvas.scale(scale);

    canvas.drawCircle(const Offset(12, 12), 10, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(12, 12), 7, Paint()..color = Colors.blue[600]!);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = bytes!.buffer.asUint8List();

    _cachedDriverDot = gmaps.BitmapDescriptor.bytes(pngBytes, imagePixelRatio: scale);
    return _cachedDriverDot!;
  }

  Future<gmaps.BitmapDescriptor> _createDemandMarker({
    required String surge,
    required String title,
    required String subtitle,
    required Color color,
  }) async {
    final cacheKey = '$surge-$title-$color';
    if (_demandMarkerCache.containsKey(cacheKey)) {
      return _demandMarkerCache[cacheKey]!;
    }

    final double scale = MediaQuery.of(context).devicePixelRatio;
    final width = (160 * scale).round();
    final height = (80 * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(ui.BlurStyle.normal, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(80, 16), width: 70, height: 22),
        const Radius.circular(12),
      ),
      shadowPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(80, 16), width: 70, height: 22),
        const Radius.circular(12),
      ),
      paint,
    );

    final surgePainter = TextPainter(
      text: TextSpan(
        text: '🔥 $surge',
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    surgePainter.layout();
    surgePainter.paint(
      canvas,
      Offset(80 - surgePainter.width / 2, 16 - surgePainter.height / 2),
    );

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: GoogleFonts.inter(
          color: Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(
      canvas,
      Offset(80 - titlePainter.width / 2, 32),
    );

    final subtitlePainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: GoogleFonts.inter(
          color: Colors.grey[800],
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    subtitlePainter.layout();
    subtitlePainter.paint(
      canvas,
      Offset(80 - subtitlePainter.width / 2, 48),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = bytes!.buffer.asUint8List();

    final descriptor = gmaps.BitmapDescriptor.bytes(pngBytes, imagePixelRatio: scale);
    _demandMarkerCache[cacheKey] = descriptor;
    return descriptor;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppStore.instance, OrderStore.instance]),
      builder: (context, _) {
        final store = AppStore.instance;

        return Scaffold(
          body: Stack(
            children: [
              // 1. Main Google Map Background
              Positioned.fill(
                child: gmaps.GoogleMap(
                  key: const ValueKey('home_map'),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: const gmaps.CameraPosition(
                    target: gmaps.LatLng(28.4595, 77.0726),
                    zoom: 12.8,
                  ),
                  markers: _markers,
                  circles: _circles,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                ),
              ),

              if (_mapLoading)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),

              // 2. Top Header Overlay (Menu, Unified Earnings/Trips Pill, Bell, Profile)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Menu Button
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.menu_rounded, color: Colors.black87),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Menu clicked')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Unified Earnings & Trips Pill
                        Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Earnings Section
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, EarningsScreen.route),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFF2C230), size: 16),
                                    const SizedBox(width: 6),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formatAmount(store.walletBalance),
                                          style: GoogleFonts.inter(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        Text(
                                          'Earnings',
                                          style: GoogleFonts.inter(
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 1,
                                height: 20,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(width: 12),
                              // Trips Section
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, IncomingParcelsScreen.route),
                                child: Row(
                                  children: [
                                    const Icon(Icons.motorcycle_rounded, color: Colors.green, size: 16),
                                    const SizedBox(width: 6),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${store.profile.totalDeliveries}',
                                          style: GoogleFonts.inter(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        Text(
                                          'Trips',
                                          style: GoogleFonts.inter(
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Notification Bell
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.notifications_none_outlined, color: Colors.black87),
                            onPressed: () => Navigator.pushNamed(context, NotificationsScreen.route),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Profile Avatar Stack with Online indicator dot
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, ProfileScreen.route),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                                  image: const DecorationImage(
                                    image: AssetImage('assets/default_profile_icon.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            if (store.isOnline)
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Online/Offline floating status dropdown selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: store.isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            store.isOnline ? 'Online' : 'Offline',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.black54),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Floating Action buttons (above bottom sheet)
              Positioned(
                bottom: 236,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // My Location Button
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.my_location_rounded, color: Colors.black87),
                        onPressed: () {
                          _mapController?.animateCamera(
                            gmaps.CameraUpdate.newLatLngZoom(
                              const gmaps.LatLng(28.4595, 77.0726),
                              12.8,
                            ),
                          );
                        },
                      ),
                    ),
                    // Filter Button
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_outlined, size: 16, color: Colors.black87),
                          const SizedBox(width: 6),
                          Text(
                            'Filter',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. White Bottom Sheet
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  height: 226,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Real-Time Next Incentive Progress card
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, EarningsScreen.route),
                          child: Builder(
                            builder: (context) {
                              final incentives = store.todayIncentives;
                              final ordersToday = incentives?.ordersToday ?? store.profile.totalDeliveries;
                              final nextTier = incentives?.nextTier;

                              final int ordersNeeded;
                              final double bonusAmount;
                              final int targetOrders;
                              final double progress;
                              final String subtitleText;

                              if (incentives != null) {
                                if (nextTier != null) {
                                  ordersNeeded = nextTier.ordersRemaining;
                                  bonusAmount = nextTier.bonus;
                                  targetOrders = ordersToday + ordersNeeded;
                                  progress = targetOrders > 0 ? (ordersToday / targetOrders).clamp(0.0, 1.0) : 0.0;
                                  subtitleText = 'Complete $ordersNeeded more ${ordersNeeded == 1 ? "trip" : "trips"} to earn ${formatAmount(bonusAmount)} Extra';
                                } else {
                                  ordersNeeded = 0;
                                  bonusAmount = incentives.targetBonusEarnedToday;
                                  targetOrders = ordersToday > 0 ? ordersToday : 20;
                                  progress = 1.0;
                                  subtitleText = '🎉 All today\'s target bonuses unlocked!';
                                }
                              } else {
                                targetOrders = ordersToday < 20 ? 20 : (ordersToday + 10);
                                ordersNeeded = (targetOrders - ordersToday).clamp(0, targetOrders);
                                bonusAmount = 300.0;
                                progress = targetOrders > 0 ? (ordersToday / targetOrders).clamp(0.0, 1.0) : 0.0;
                                subtitleText = ordersNeeded > 0
                                    ? 'Complete $ordersNeeded more ${ordersNeeded == 1 ? "trip" : "trips"} to earn ${formatAmount(bonusAmount)} Extra'
                                    : 'Incentive target completed!';
                              }

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9E7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFF2C230).withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.card_giftcard_rounded,
                                            size: 18,
                                            color: Color(0xFFF2C230),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    'Next Incentive',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  if (incentives != null && incentives.isPeakHourNow) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        '🔥 Peak Hour',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w800,
                                                          color: Colors.deepOrange,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                subtitleText,
                                                style: GoogleFonts.inter(
                                                  fontSize: 10.5,
                                                  color: Colors.grey[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '$ordersToday / $targetOrders Trips',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.black54),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.black12,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF2C230)),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SwipeOnlineBanner(
                          isOnline: store.isOnline,
                          onSwiped: () {
                            store.setOnline(!store.isOnline);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: const BottomNav(currentIndex: 0),
        );
      },
    );
  }
}

class _SwipeOnlineBanner extends StatefulWidget {
  final bool isOnline;
  final VoidCallback onSwiped;

  const _SwipeOnlineBanner({
    required this.isOnline,
    required this.onSwiped,
  });

  @override
  State<_SwipeOnlineBanner> createState() => _SwipeOnlineBannerState();
}

class _SwipeOnlineBannerState extends State<_SwipeOnlineBanner> with SingleTickerProviderStateMixin {
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
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SwipeOnlineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnline != oldWidget.isOnline) {
      setState(() {
        _confirmed = false;
        _dragPosition = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const handleWidth = 40.0;
    const padding = 14.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = (constraints.maxWidth - handleWidth - (padding * 2)).clamp(0.0, double.infinity);
        final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          width: double.infinity,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: padding),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Center Text Details
              Positioned(
                left: 54,
                right: 28,
                child: Opacity(
                  opacity: (1.0 - progress).clamp(0.2, 1.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.isOnline ? 'You are Online' : 'You are Offline',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isOnline
                            ? 'Swipe handle right to go offline'
                            : 'Swipe handle right to go online',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right Chevron indicator
              Positioned(
                right: 0,
                child: Opacity(
                  opacity: (1.0 - progress).clamp(0.2, 1.0),
                  child: const Icon(Icons.chevron_right_rounded, color: Colors.black54),
                ),
              ),

              // Draggable Power Circle
              Positioned(
                left: _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_confirmed) return;
                    setState(() {
                      _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_confirmed) return;
                    if (_dragPosition >= maxDrag * 0.75) {
                      setState(() => _confirmed = true);
                      widget.onSwiped();

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
                  },
                  child: Container(
                    width: handleWidth,
                    height: handleWidth,
                    decoration: BoxDecoration(
                      color: widget.isOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFDECEA),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        )
                      ],
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 20,
                      color: widget.isOnline ? Colors.green[700]! : Colors.red[700]!,
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
