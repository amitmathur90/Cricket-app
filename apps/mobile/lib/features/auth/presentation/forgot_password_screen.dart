import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../application/auth_providers.dart';

enum _Step { identifier, otp, newPassword, success }

/// The full "Forgot password" wizard in one screen (same "one route, an
/// internal step index" pattern as other multi-step flows in this app, e.g.
/// CreateTournamentScreen) — Step 1 (email/phone) -> Step 2 (6-digit OTP,
/// emailed by MailService) -> Step 3 (new password) -> success, mirroring
/// AuthController's forgot-password/verify-otp/reset-password endpoints
/// one-to-one.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _Step _step = _Step.identifier;
  bool _busy = false;
  String? _error;

  final _identifierController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _resetToken;

  @override
  void dispose() {
    _identifierController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  Future<void> _submitIdentifier() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      setState(() => _error = 'Enter your registered email or mobile number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(identifier);
      if (!mounted) return;
      setState(() => _step = _Step.otp);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitOtp() async {
    final otp = _otp;
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resetToken = await ref.read(authRepositoryProvider).verifyPasswordResetOtp(
            identifier: _identifierController.text.trim(),
            otp: otp,
          );
      if (!mounted) return;
      setState(() {
        _resetToken = resetToken;
        _step = _Step.newPassword;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(_identifierController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('A new code has been sent')));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitNewPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (newPassword.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    final resetToken = _resetToken;
    if (resetToken == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            resetToken: resetToken,
            newPassword: newPassword,
          );
      if (!mounted) return;
      setState(() => _step = _Step.success);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: switch (_step) {
              _Step.identifier => _IdentifierStep(
                  controller: _identifierController,
                  busy: _busy,
                  error: _error,
                  onContinue: _submitIdentifier,
                ),
              _Step.otp => _OtpStep(
                  controllers: _otpControllers,
                  focusNodes: _otpFocusNodes,
                  busy: _busy,
                  error: _error,
                  onChanged: _onOtpChanged,
                  onVerify: _submitOtp,
                  onResend: _resendOtp,
                ),
              _Step.newPassword => _NewPasswordStep(
                  newPasswordController: _newPasswordController,
                  confirmPasswordController: _confirmPasswordController,
                  obscureNewPassword: _obscureNewPassword,
                  obscureConfirmPassword: _obscureConfirmPassword,
                  onToggleObscureNew: () =>
                      setState(() => _obscureNewPassword = !_obscureNewPassword),
                  onToggleObscureConfirm: () =>
                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  busy: _busy,
                  error: _error,
                  onSubmit: _submitNewPassword,
                ),
              _Step.success => _SuccessStep(onGoToLogin: () => context.go(loginPath)),
            },
          ),
        ),
      ),
    );
  }
}

class _IdentifierStep extends StatelessWidget {
  const _IdentifierStep({
    required this.controller,
    required this.busy,
    required this.error,
    required this.onContinue,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Forgot password', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Enter your registered email or mobile number'),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Email / Mobile'),
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => busy ? null : onContinue(),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onContinue,
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.controllers,
    required this.focusNodes,
    required this.busy,
    required this.error,
    required this.onChanged,
    required this.onVerify,
    required this.onResend,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool busy;
  final String? error;
  final void Function(int index, String value) onChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Verify your identity', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Enter the 6-digit code sent to your email'),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 6; i++)
              SizedBox(
                width: 44,
                child: TextField(
                  controller: controllers[i],
                  focusNode: focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: ''),
                  style: Theme.of(context).textTheme.titleLarge,
                  onChanged: (v) => onChanged(i, v),
                ),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onVerify,
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify OTP'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy ? null : onResend,
          child: const Text("Didn't get a code? Resend"),
        ),
      ],
    );
  }
}

class _NewPasswordStep extends StatelessWidget {
  const _NewPasswordStep({
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.obscureNewPassword,
    required this.obscureConfirmPassword,
    required this.onToggleObscureNew,
    required this.onToggleObscureConfirm,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final VoidCallback onToggleObscureNew;
  final VoidCallback onToggleObscureConfirm;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Create new password', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        TextField(
          controller: newPasswordController,
          obscureText: obscureNewPassword,
          decoration: InputDecoration(
            labelText: 'New password',
            helperText: 'At least 8 characters',
            suffixIcon: IconButton(
              icon: Icon(obscureNewPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: onToggleObscureNew,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: confirmPasswordController,
          obscureText: obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm password',
            suffixIcon: IconButton(
              icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: onToggleObscureConfirm,
            ),
          ),
          onSubmitted: (_) => busy ? null : onSubmit(),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reset password'),
        ),
      ],
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.onGoToLogin});

  final VoidCallback onGoToLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 64),
        const SizedBox(height: 16),
        Text(
          'Password reset successfully',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Your password has been updated.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(onPressed: onGoToLogin, child: const Text('Go to login')),
      ],
    );
  }
}
