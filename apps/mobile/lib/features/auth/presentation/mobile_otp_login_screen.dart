import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../application/auth_providers.dart';
import '../application/session_controller.dart';

enum _Step { phone, otp }

/// "Login with mobile OTP" — Step 1 (phone) texts a 6-digit OTP via
/// SmsService/Renflair, Step 2 (OTP) logs in directly on success (see
/// SessionController.loginWithMobileOtp). Same "one route, internal step
/// index" pattern as ForgotPasswordScreen; unlike that flow, a successful
/// verify here changes AuthStatus to authenticated, so the router's own
/// redirect takes the user to their home screen — no explicit navigation
/// call needed in this widget.
class MobileOtpLoginScreen extends ConsumerStatefulWidget {
  const MobileOtpLoginScreen({super.key});

  @override
  ConsumerState<MobileOtpLoginScreen> createState() => _MobileOtpLoginScreenState();
}

class _MobileOtpLoginScreenState extends ConsumerState<MobileOtpLoginScreen> {
  _Step _step = _Step.phone;
  bool _requestBusy = false;
  String? _requestError;

  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  Future<void> _submitPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _requestError = 'Enter your registered mobile number');
      return;
    }
    setState(() {
      _requestBusy = true;
      _requestError = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestMobileLoginOtp(phone);
      if (!mounted) return;
      setState(() => _step = _Step.otp);
    } on ApiException catch (e) {
      setState(() => _requestError = e.message);
    } finally {
      if (mounted) setState(() => _requestBusy = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _requestBusy = true;
      _requestError = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestMobileLoginOtp(_phoneController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('A new code has been sent')));
    } on ApiException catch (e) {
      setState(() => _requestError = e.message);
    } finally {
      if (mounted) setState(() => _requestBusy = false);
    }
  }

  Future<void> _submitOtp() async {
    final otp = _otp;
    if (otp.length != 6) {
      setState(() => _requestError = 'Enter the 6-digit code');
      return;
    }
    await ref.read(sessionControllerProvider.notifier).loginWithMobileOtp(
          phone: _phoneController.text.trim(),
          otp: otp,
        );
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);

    ref.listen<SessionState>(sessionControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Login with mobile OTP')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _step == _Step.phone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Login with mobile OTP', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text('Enter your registered mobile number'),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(labelText: 'Mobile number'),
                        keyboardType: TextInputType.phone,
                        onSubmitted: (_) => _requestBusy ? null : _submitPhone(),
                      ),
                      if (_requestError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _requestError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _requestBusy ? null : _submitPhone,
                        child: _requestBusy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send OTP'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Enter the code', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text('Enter the 6-digit code sent to your mobile number'),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var i = 0; i < 6; i++)
                            SizedBox(
                              width: 44,
                              child: TextField(
                                controller: _otpControllers[i],
                                focusNode: _otpFocusNodes[i],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                decoration: const InputDecoration(counterText: ''),
                                style: Theme.of(context).textTheme.titleLarge,
                                onChanged: (v) => _onOtpChanged(i, v),
                              ),
                            ),
                        ],
                      ),
                      if (_requestError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _requestError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: session.isBusy ? null : _submitOtp,
                        child: session.isBusy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Verify & login'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _requestBusy ? null : _resendOtp,
                        child: const Text("Didn't get a code? Resend"),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
