import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Authentication screen — Phone + PIN login followed by OTP verification.
/// Mirrors the Auth.tsx component from sample_files/kijani-finance.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  bool _showOtp = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<ThemeProvider>().config;
    final colors = config.colors;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              // ── Branding ────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 18),
                    Text(
                      config.displayName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 4),
                    Text(
                      config.tagline,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // ── Form (animated switch between login and OTP) ──────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.08, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _showOtp
                    ? _OtpCard(
                        key: const ValueKey('otp'),
                        phone: _phoneController.text,
                        controllers: _otpControllers,
                        onVerify: () =>
                            context.read<ThemeProvider>().onLoginSuccess(),
                        onBack: () => setState(() => _showOtp = false),
                        primaryColor: colors.primary,
                      )
                    : _LoginCard(
                        key: const ValueKey('login'),
                        phoneController: _phoneController,
                        pinController: _pinController,
                        onSubmit: () => setState(() => _showOtp = true),
                        primaryColor: colors.primary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Login card ─────────────────────────────────────────────────────────────────

class _LoginCard extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController pinController;
  final VoidCallback onSubmit;
  final Color primaryColor;

  const _LoginCard({
    super.key,
    required this.phoneController,
    required this.pinController,
    required this.onSubmit,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Phone Number',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixText: '+254 ',
                hintText: '712 345 678',
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Security PIN',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pinController,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
                hintText: '••••',
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onSubmit,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Sign In'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text(
                    '— or use biometrics —',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: onSubmit,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.all(16),
                      shape: const CircleBorder(),
                      side: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    child: Icon(Icons.fingerprint, size: 34, color: primaryColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OTP card ───────────────────────────────────────────────────────────────────

class _OtpCard extends StatelessWidget {
  final String phone;
  final List<TextEditingController> controllers;
  final VoidCallback onVerify;
  final VoidCallback onBack;
  final Color primaryColor;

  const _OtpCard({
    super.key,
    required this.phone,
    required this.controllers,
    required this.onVerify,
    required this.onBack,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text(
                'Verify Identity',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "We've sent a 6-digit code to\n+254 $phone",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                6,
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 44,
                    child: TextField(
                      controller: controllers[i],
                      maxLength: 1,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofocus: i == 0,
                      decoration: const InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (val) {
                        // Auto-advance focus to the next field
                        if (val.isNotEmpty && i < 5) {
                          FocusScope.of(context).nextFocus();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onVerify,
              child: const Text('Verify & Continue'),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: onBack,
                child: Text('Back', style: TextStyle(color: primaryColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
