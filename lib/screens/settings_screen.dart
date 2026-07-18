import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_store.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  Future<void> _pickLanguage(BuildContext context) async {
    const options = ['English', 'हिन्दी'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Language'),
        children: options
            .map(
              (o) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, o),
                child: Row(
                  children: [
                    if (AppStore.instance.language == o)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.check_rounded, size: 18, color: AppColors.primaryDark),
                      ),
                    Text(o),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      AppStore.instance.setLanguage(selected);
    }
  }

  void _showLegal(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(
              'Settings',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                _SettingsRow(
                  label: 'Language',
                  trailing: Text(
                    store.language,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () => _pickLanguage(context),
                ),
                _SettingsRow(
                  label: 'Dark Mode',
                  trailing: _YellowSwitch(
                    value: store.darkMode,
                    onChanged: store.setDarkMode,
                  ),
                ),
                _SettingsRow(
                  label: 'Notifications',
                  trailing: _YellowSwitch(
                    value: store.notificationsEnabled,
                    onChanged: store.setNotificationsEnabled,
                  ),
                ),
                _SettingsRow(
                  label: 'Privacy Policy',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                  onTap: () => _showLegal(
                    context,
                    'Privacy Policy',
                    'SHIPRYD Partner collects only the delivery, location and KYC '
                        'data required to operate the parcel-handover workflow. '
                        'Your data is never sold to third parties.',
                  ),
                ),
                _SettingsRow(
                  label: 'Terms & Conditions',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                  onTap: () => _showLegal(
                    context,
                    'Terms & Conditions',
                    'By using SHIPRYD Partner you agree to handle parcels with '
                        'due care, confirm receipt honestly, and keep your KYC '
                        'and bank details up to date.',
                  ),
                ),
                _SettingsRow(
                  label: 'About Shipryd Partner',
                  trailing: Text(
                    'v1.0.0',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
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
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _YellowSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _YellowSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: AppColors.primary,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFE4E4E7),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}
