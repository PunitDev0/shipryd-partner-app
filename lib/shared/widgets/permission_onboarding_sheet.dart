import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Permission data model for each permission card
class _PermissionItem {
  final Permission permission;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String reason;

  const _PermissionItem({
    required this.permission,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.reason,
  });
}

/// Shows the permission onboarding bottom sheet on first launch.
/// Call [PermissionOnboardingSheet.showIfNeeded] from DashboardScreen.
class PermissionOnboardingSheet extends StatefulWidget {
  const PermissionOnboardingSheet({super.key});

  static const String _prefsKey = 'permissions_onboarded_v1';

  /// Check SharedPrefs and show the sheet only on first launch.
  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey) == true) return;
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => const PermissionOnboardingSheet(),
    );
    await prefs.setBool(_prefsKey, true);
  }

  @override
  State<PermissionOnboardingSheet> createState() => _PermissionOnboardingSheetState();
}

class _PermissionOnboardingSheetState extends State<PermissionOnboardingSheet>
    with TickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool _requesting = false;

  static const List<_PermissionItem> _permissions = [
    _PermissionItem(
      permission: Permission.locationWhenInUse,
      icon: Icons.location_on_rounded,
      iconBg: Color(0xFFE8F5E9),
      iconColor: Color(0xFF2E7D32),
      title: 'Location Access',
      reason: 'To show your live position on the map, calculate routes to customers, and update your tracking in real-time.',
    ),
    _PermissionItem(
      permission: Permission.camera,
      icon: Icons.qr_code_scanner_rounded,
      iconBg: Color(0xFFE3F2FD),
      iconColor: Color(0xFF1565C0),
      title: 'Camera & QR Scanner',
      reason: 'To scan parcel QR codes at pickup and delivery points for secure, fast verification.',
    ),
    _PermissionItem(
      permission: Permission.notification,
      icon: Icons.notifications_active_rounded,
      iconBg: Color(0xFFFFF3E0),
      iconColor: Color(0xFFE65100),
      title: 'Push Notifications',
      reason: 'To receive instant alerts for new orders, pickup requests, and important status updates even when the app is in background.',
    ),
    _PermissionItem(
      permission: Permission.phone,
      icon: Icons.phone_in_talk_rounded,
      iconBg: Color(0xFFF3E5F5),
      iconColor: Color(0xFF6A1B9A),
      title: 'Phone Access',
      reason: 'To detect incoming calls during navigation so we can pause the ride safely and avoid distractions.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _requestAllPermissions() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    // Request location first
    await Permission.locationWhenInUse.request();

    // Background location — Android requires explicit separate request after fine location
    final locStatus = await Permission.locationWhenInUse.status;
    if (locStatus.isGranted) {
      await Permission.locationAlways.request();
    }

    // Camera
    await Permission.camera.request();

    // Notifications (Android 13+)
    await Permission.notification.request();

    // Phone
    await Permission.phone.request();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safePadding = MediaQuery.of(context).padding.bottom;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: safePadding + bottomInset + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header illustration
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF0288D1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0288D1).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Before We Start',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ShipRYD Partner needs a few permissions\nto give you the best experience.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF7B7B8E),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Permission cards
                ..._permissions.map((p) => _PermissionCard(item: p)),

                const SizedBox(height: 28),

                // CTA Button
                AnimatedScale(
                  scale: _requesting ? 0.97 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _requesting ? null : _requestAllPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: const Color(0xFF1A237E).withValues(alpha: 0.7),
                      ),
                      child: _requesting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Allow All Permissions',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: _requesting ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Skip for now',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF9E9E9E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final _PermissionItem item;
  const _PermissionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEBF5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.reason,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFF7B7B8E),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
