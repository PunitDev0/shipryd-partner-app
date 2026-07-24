import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';


import 'package:partner/core/push_notifications.dart';
import 'package:partner/features/notifications/presentation/notifications_screen.dart';
import 'package:partner/features/onboarding/presentation/login_screen.dart';
import 'package:partner/features/onboarding/presentation/register_screen.dart';
import 'package:partner/features/onboarding/presentation/registration_partner_type_screen.dart';
import 'package:partner/features/onboarding/presentation/registration_vehicle_screen.dart';
import 'package:partner/features/orders/presentation/dashboard_screen.dart';
import 'package:partner/features/orders/presentation/incoming_parcels_screen.dart';
import 'package:partner/features/orders/presentation/parcel_history_screen.dart';
import 'package:partner/features/parcel/presentation/scan_parcel_screen.dart';
import 'package:partner/features/profile/presentation/bank_details_screen.dart';
import 'package:partner/features/profile/presentation/logout_screen.dart';
import 'package:partner/features/profile/presentation/profile_screen.dart';
import 'package:partner/features/profile/presentation/settings_screen.dart';
import 'package:partner/features/profile/presentation/vehicle_info_screen.dart';
import 'package:partner/features/support/presentation/help_center_screen.dart';
import 'package:partner/features/support/presentation/support_screen.dart';
import 'package:partner/features/wallet/presentation/earnings_screen.dart';
import 'package:partner/features/wallet/presentation/ratings_screen.dart';
import 'package:partner/features/wallet/presentation/transactions_screen.dart';
import 'package:partner/features/wallet/presentation/wallet_screen.dart';
import 'package:partner/shared/state/app_store.dart';
import 'package:partner/shared/state/order_store.dart';
import 'package:partner/shared/theme/app_colors.dart';
import 'package:partner/shared/widgets/incoming_order_overlay.dart';

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

  AppStore.instance.init(); // Run initialization in parallel (non-blocking)
  runApp(const ShiprydPartnerApp());
}

class ShiprydPartnerApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const ShiprydPartnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return AnimatedBuilder(
      animation: Listenable.merge([AppStore.instance, OrderStore.instance]),
      builder: (context, _) {
        final store = AppStore.instance;
        final dark = store.darkMode;
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'ShipRyd Partner',
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
          home: !store.isLoggedIn
              ? const LoginScreen()
              : store.isRegistered
                  ? const DashboardScreen()
                  : const RegistrationPartnerTypeScreen(),
          routes: {
            LoginScreen.route: (_) => const LoginScreen(),
            RegisterScreen.route: (_) => const RegisterScreen(),
            RegistrationVehicleScreen.route: (_) => const RegistrationVehicleScreen(),
            RegistrationPartnerTypeScreen.route: (_) => const RegistrationPartnerTypeScreen(),
            DashboardScreen.route: (_) => const DashboardScreen(),
            IncomingParcelsScreen.route: (_) => const IncomingParcelsScreen(),
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
                if (OrderStore.instance.activeOffer != null)
                  IncomingOrderOverlay(
                    key: ValueKey(OrderStore.instance.activeOffer!.id),
                    order: OrderStore.instance.activeOffer!,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
