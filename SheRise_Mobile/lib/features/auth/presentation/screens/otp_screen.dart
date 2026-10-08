import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String phone;
  final String name;
  final bool isRegister;

  const OtpScreen({
    super.key,
    required this.email,
    required this.phone,
    required this.name,
    required this.isRegister,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpController = TextEditingController();
  bool _canResend = false;
  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendSeconds = 60;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) {
        setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  void _onVerify() async {
    if (_otpController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).verifyOtp(
          email: widget.email,
          phone: widget.phone.isNotEmpty ? widget.phone : null,
          otp: _otpController.text.trim(),
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Login successful! Welcome to SheRise.'),
        ),
      );
      context.go('/');
    }
  }

  void _onResend() async {
    if (!_canResend) return;

    final success = await ref.read(authProvider.notifier).sendOtp(
          email: widget.email,
          phone: widget.phone.isNotEmpty ? widget.phone : null,
          isRegister: widget.isRegister,
        );

    if (success && mounted) {
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
    );

    ref.listen(authProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Verification Code',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to ${widget.email}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 40),
              Center(
                child: Pinput(
                  controller: _otpController,
                  length: 6,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  errorPinTheme: defaultPinTheme.copyDecorationWith(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                  onCompleted: (_) => _onVerify(),
                ),
              ),
              const SizedBox(height: 40),
              AuthButton(
                text: 'Verify OTP',
                onPressed: _onVerify,
                isLoading: authState.isLoading,
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _canResend ? _onResend : null,
                  child: Text(
                    _canResend
                        ? 'Resend OTP'
                        : 'Resend in $_resendSeconds seconds',
                    style: TextStyle(
                      color: _canResend
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withAlpha(128),
                    ),
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
