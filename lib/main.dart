import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/push_notifications.dart';
import 'data/app_store.dart';
import 'theme/app_colors.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/registration_vehicle_screen.dart';
import 'screens/registration_partner_type_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/incoming_parcels_screen.dart';
import 'screens/scan_parcel_screen.dart';
import 'screens/parcel_history_screen.dart';
import 'screens/earnings_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/bank_details_screen.dart';
import 'screens/vehicle_info_screen.dart';
import 'screens/support_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/help_center_screen.dart';
import 'screens/logout_screen.dart';
import 'screens/ratings_screen.dart';
import 'widgets/incoming_order_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await AppStore.instance.init();
  runApp(const ShiprydPartnerApp());
}

class ShiprydPartnerApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const ShiprydPartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        final dark = store.darkMode;
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'SHIPRYD Partner',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: dark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            textTheme: baseTextTheme.apply(
              bodyColor: AppColors.textPrimary,
              displayColor: AppColors.textPrimary,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              iconTheme: IconThemeData(color: AppColors.textPrimary),
            ),
          ),
          initialRoute: SplashScreen.route,
          routes: {
            SplashScreen.route: (_) => const SplashScreen(),
            LoginScreen.route: (_) => const LoginScreen(),
            RegisterScreen.route: (_) => const RegisterScreen(),
            RegistrationVehicleScreen.route: (_) => const RegistrationVehicleScreen(),
            RegistrationPartnerTypeScreen.route: (_) => const RegistrationPartnerTypeScreen(),
            DashboardScreen.route: (_) => const DashboardScreen(),
            IncomingParcelsScreen.route: (_) => const IncomingParcelsScreen(),
            ScanParcelScreen.route: (_) => const ScanParcelScreen(),
            ParcelHistoryScreen.route: (_) => const ParcelHistoryScreen(),
            EarningsScreen.route: (_) => const EarningsScreen(),
            WalletScreen.route: (_) => const WalletScreen(),
            TransactionsScreen.route: (_) => const TransactionsScreen(),
            ProfileScreen.route: (_) => const ProfileScreen(),
            BankDetailsScreen.route: (_) => const BankDetailsScreen(),
            VehicleInfoScreen.route: (_) => const VehicleInfoScreen(),
            SupportScreen.route: (_) => const SupportScreen(),
            NotificationsScreen.route: (_) => const NotificationsScreen(),
            SettingsScreen.route: (_) => const SettingsScreen(),
            HelpCenterScreen.route: (_) => const HelpCenterScreen(),
            LogoutScreen.route: (_) => const LogoutScreen(),
            RatingsScreen.route: (_) => const RatingsScreen(),
          },
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                if (store.activeRequest != null)
                  IncomingOrderOverlay(
                    key: ValueKey(store.activeRequest!.id),
                    parcel: store.activeRequest!,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
