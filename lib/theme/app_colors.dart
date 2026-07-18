import 'package:flutter/material.dart';
import '../data/app_store.dart';

/// Theme colors used across the app. These are getters (not const) so that
/// toggling dark mode in Settings — which calls `AppStore.notifyListeners()`
/// — causes every screen (rebuilt via the top-level `AnimatedBuilder` in
/// main.dart) to pick up the correct palette without each screen needing to
/// know about the theme itself.
class AppColors {
  AppColors._();

  static bool get _dark => AppStore.instance.darkMode;

  // Brand (unaffected by theme)
  static const Color primary = Color(0xFFF2C230);
  static const Color primaryDark = Color(0xFFE0B01E);
  static Color get primaryLight => _dark ? const Color(0xFF3A331A) : const Color(0xFFFDF3D0);

  static const Color black = Color(0xFF1A1A1A);

  static Color get textPrimary => _dark ? const Color(0xFFF2F2F2) : const Color(0xFF1A1A1A);
  static Color get textSecondary => _dark ? const Color(0xFFA5A5A5) : const Color(0xFF8A8A8A);
  static Color get textTertiary => _dark ? const Color(0xFF737373) : const Color(0xFFB5B5B5);

  static Color get background => _dark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
  static Color get scaffoldBg => _dark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
  static Color get cardBg => _dark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  static Color get inputBg => _dark ? const Color(0xFF262626) : const Color(0xFFF5F5F5);
  static Color get border => _dark ? const Color(0xFF2E2E2E) : const Color(0xFFEDEDED);

  static const Color success = Color(0xFF2E7D32);
  static const Color scannerOverlay = Color(0xFF3A362E);
}
