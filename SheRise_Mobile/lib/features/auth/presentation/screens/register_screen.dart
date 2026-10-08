import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/she_rise_top_bar.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String email;
  final String phone;

  const RegisterScreen({
    super.key,
    this.email = '',
    this.phone = '',
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController(text: 'Madhapur, Hyderabad');
  final _otpController = TextEditingController();

  bool _isDigilockerVerified = false;
  bool _isVerifyingDigiLocker = false;
  bool _otpSent = false;
  bool _isSendingOtp = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
    _phoneController.text = widget.phone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onDigiLockerVerify() async {
    setState(() => _isVerifyingDigiLocker = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() {
        _isVerifyingDigiLocker = false;
        _isDigilockerVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.emeraldGreen,
          content: Text('✓ Aadhaar DigiLocker verification simulated successfully!'),
        ),
      );
    }
  }

  void _onSendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.darkSlate,
          content: Text('Please enter email first'),
        ),
      );
      return;
    }

    setState(() => _isSendingOtp = true);
    final success = await ref.read(authProvider.notifier).sendOtpRegister(
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
        );
    setState(() => _isSendingOtp = false);

    if (success && mounted) {
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.emeraldGreen,
          content: Text('Verification code sent! (Use 123456)'),
        ),
      );
    }
  }

  void _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          gender: 'F',
        );

    if (success && mounted) {
      if (_otpSent && _otpController.text.trim().isNotEmpty) {
        await ref.read(authProvider.notifier).verifyOtp(
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim(),
              otp: _otpController.text.trim(),
            );
        if (mounted) context.go('/take-work');
      } else {
        context.push('/otp', extra: {
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'name': _nameController.text.trim(),
          'isRegister': true,
        });
      }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            // Pill Badge: [ ✨ WOMEN EMPOWERMENT NETWORK ]
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
                  Text('✨', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 6),
                  Text(
                    'WOMEN EMPOWERMENT NETWORK',
                    style: TextStyle(
                      color: AppTheme.deepRose,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // White Registration Card
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(24),
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
                    Center(
                      child: Text(
                        'Register',
                        style: AppTheme.serifTitle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Join thousands of independent women earning with dignity',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g., Lakshmi Devi',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 14),

                    // Email Address
                    const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 14),

                    // Phone Number
                    const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: Validators.phone,
                    ),
                    const SizedBox(height: 14),

                    // OTP Verification Box
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Enter OTP sent to email',
                              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              filled: true,
                              fillColor: AppTheme.inputBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppTheme.inputBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: AppTheme.inputBorder),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isSendingOtp ? null : _onSendOtp,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.peachButton,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFDBA74)),
                            ),
                            alignment: Alignment.center,
                            child: _isSendingOtp
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF9A3412)),
                                  )
                                : Text(
                                    _otpSent ? 'Resend' : 'Send OTP',
                                    style: const TextStyle(
                                      color: Color(0xFF9A3412),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Address / City
                    const Text('Address / Service Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText: 'Locality, City (e.g. Madhapur, Hyderabad)',
                        hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.location_on_outlined, color: AppTheme.deepRose, size: 20),
                        filled: true,
                        fillColor: AppTheme.inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.inputBorder),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Please enter address' : null,
                    ),
                    const SizedBox(height: 18),

                    // DigiLocker KYC Card matching Web App
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: AppTheme.digilockerBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_user, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Verify Your Identity (DigiLocker)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Instantly verify your Aadhaar via DigiLocker to earn a verified trust badge and higher client visibility.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), height: 1.3),
                          ),
                          const SizedBox(height: 12),
                          if (_isDigilockerVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.emeraldGreen.withAlpha(25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.emeraldGreen),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: AppTheme.emeraldGreen, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Verified with DigiLocker',
                                    style: TextStyle(
                                      color: AppTheme.emeraldGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.digilockerBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: _isVerifyingDigiLocker
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.security, size: 16),
                                label: Text(
                                  _isVerifyingDigiLocker ? 'Connecting to DigiLocker...' : 'Verify with DigiLocker',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                onPressed: _isVerifyingDigiLocker ? null : _onDigiLockerVerify,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Solid Navy Button: [ Complete Registration -> ]
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkSlate,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        onPressed: authState.isLoading ? null : _onRegister,
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Complete Registration',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Already have an account? Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/login'),
                          child: const Text(
                            'Login',
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
    );
  }
}
