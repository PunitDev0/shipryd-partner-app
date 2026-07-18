import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/app_store.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'registration_partner_type_screen.dart';

class OtpScreen extends StatefulWidget {
  static const route = '/otp';
  final String phone;
  final bool isRegister;
  const OtpScreen({super.key, required this.phone, this.isRegister = false});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _otp = '';
  int _secondsLeft = 30;
  Timer? _timer;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
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

  void _onKeyTap(String value) {
    if (_verifying) return;
    if (value == 'back') {
      if (_otp.isNotEmpty) {
        setState(() => _otp = _otp.substring(0, _otp.length - 1));
      }
      return;
    }
    if (_otp.length < 6) {
      setState(() => _otp += value);
      if (_otp.length == 6) {
        Future.delayed(const Duration(milliseconds: 300), () async {
          if (!mounted) return;
          setState(() => _verifying = true);
          final ok = await AppStore.instance.verifyOtp(
            phone: widget.phone,
            otp: _otp,
            isRegister: widget.isRegister,
          );
          if (!mounted) return;
          if (!ok) {
            setState(() {
              _verifying = false;
              _otp = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStore.instance.lastAuthError ?? 'Invalid OTP. Please try again.')),
            );
            return;
          }
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppStore.instance.isRegistered ? DashboardScreen.route : RegistrationPartnerTypeScreen.route,
            (route) => false,
          );
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    await AppStore.instance.sendOtp(widget.phone);
    if (!mounted) return;
    setState(_startTimer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Enter OTP',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We have sent OTP on',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                widget.phone,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 36),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final filled = i < _otp.length;
                  final isActive = i == _otp.length;
                  return Container(
                    width: 48,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? AppColors.primary
                            : AppColors.border,
                        width: 1.6,
                      ),
                    ),
                    child: Text(
                      filled ? _otp[i] : '',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),
              if (_verifying)
                const Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary),
                  ),
                ),
              const SizedBox(height: 8),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Resend OTP in 00:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : GestureDetector(
                        onTap: _resendOtp,
                        child: Text(
                          'Resend OTP',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
              ),

              const Spacer(),

              // Custom numeric keypad
              _NumericKeypad(onKeyTap: _onKeyTap),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  final void Function(String) onKeyTap;
  const _NumericKeypad({required this.onKeyTap});

  static const _subLabels = {
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
  };

  @override
  Widget build(BuildContext context) {
    Widget key(String value, {IconData? icon, bool filled = true}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: filled ? const Color(0xFFF2F2F4) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onKeyTap(value),
              child: SizedBox(
                height: 52,
                child: icon != null
                    ? Icon(icon, size: 22, color: AppColors.textPrimary)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            value,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                          if (_subLabels[value] != null)
                            Text(
                              _subLabels[value]!,
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                letterSpacing: 1.2,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    }

    Widget spacer() => const Expanded(child: SizedBox());

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(children: [key('1'), key('2'), key('3')]),
          Row(children: [key('4'), key('5'), key('6')]),
          Row(children: [key('7'), key('8'), key('9')]),
          Row(children: [
            spacer(),
            key('0'),
            key('back', icon: Icons.backspace_outlined, filled: false),
          ]),
        ],
      ),
    );
  }
}
