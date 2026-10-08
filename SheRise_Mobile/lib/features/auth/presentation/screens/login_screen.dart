import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/she_rise_top_bar.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isSendingOtp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final otp = _otpController.text.trim();

    if (_otpSent && otp.isNotEmpty) {
      final success = await ref.read(authProvider.notifier).verifyOtp(
            email: email,
            phone: phone,
            otp: otp,
          );
      if (success && mounted) {
        context.go('/take-work');
      }
    } else {
      await ref.read(authProvider.notifier).login(
            email: email,
            phone: phone,
            name: name,
          );
    }
  }

  void _onSendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.darkSlate,
          content: Text('Please enter your email to receive OTP'),
        ),
      );
      return;
    }

    setState(() => _isSendingOtp = true);

    final success = await ref.read(authProvider.notifier).sendOtp(
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        );

    setState(() => _isSendingOtp = false);

    if (success && mounted) {
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.emeraldGreen,
          content: Text('OTP sent successfully! Check your email or console (123456)'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        context.go('/take-work');
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      appBar: const SheRiseTopBar(showBackButton: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Exact Web Checkmark Pill: [ ✓ Earn From Home ]
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryRose, width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.emeraldGreen, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Earn From Home',
                      style: TextStyle(
                        color: AppTheme.darkSlate,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // White Login Card matching Web App
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.cardBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Serif Title
                      Center(
                        child: Text(
                          'Login',
                          style: AppTheme.serifTitle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Enter your details to access your account',
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      const Text(
                        'Full Name',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkSlate),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Your registered name',
                          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.inputBorder),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        validator: Validators.name,
                      ),
                      const SizedBox(height: 16),

                      // Email Address
                      const Text(
                        'Email Address',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkSlate),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'name@example.com',
                          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.inputBorder),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),

                      // Phone Number
                      const Text(
                        'Phone Number',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkSlate),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '+91 98765 43210',
                          hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.inputBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(color: AppTheme.inputBorder),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        validator: Validators.phone,
                      ),
                      const SizedBox(height: 16),

                      // Enter OTP row with Peach "Send OTP" Button
                      const Text(
                        'Enter OTP',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkSlate),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '6-digit OTP',
                                hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                filled: true,
                                fillColor: AppTheme.inputBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: AppTheme.inputBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: AppTheme.inputBorder),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _isSendingOtp ? null : _onSendOtp,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppTheme.peachButton,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFFDBA74)),
                              ),
                              alignment: Alignment.center,
                              child: _isSendingOtp
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9A3412)),
                                    )
                                  : Text(
                                      _otpSent ? 'Resend' : 'Send OTP',
                                      style: const TextStyle(
                                        color: Color(0xFF9A3412),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Solid Navy Pill Button: [ Login -> ]
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.darkSlate,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          onPressed: authState.isLoading ? null : _onLogin,
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Login', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Don't have an account? Register
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/register'),
                            child: const Text(
                              'Register',
                              style: TextStyle(
                                color: AppTheme.deepRose,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
