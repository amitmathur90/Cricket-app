import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../application/organizations_providers.dart';

/// Reached from OrgSelectScreen / CreateOrganizationScreen's "Join with a
/// code" option — lets a user self-join an organization via its join code
/// (POST /organizations/join, auto-creates an ACTIVE `player`-role
/// membership — see OrganizationsService.join), then hands off to
/// SessionController.selectOrg to activate it, same post-action navigation
/// CreateOrganizationScreen uses after POST /organizations succeeds.
class JoinOrganizationScreen extends ConsumerStatefulWidget {
  const JoinOrganizationScreen({super.key});

  @override
  ConsumerState<JoinOrganizationScreen> createState() => _JoinOrganizationScreenState();
}

class _JoinOrganizationScreenState extends ConsumerState<JoinOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      final org = await ref
          .read(organizationsRepositoryProvider)
          .join(_codeController.text.trim());
      if (!mounted) return;
      await ref.read(sessionControllerProvider.notifier).selectOrg(org.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider);
    final busy = _submitting || session.isBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('Join an organization')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter the join code shared by your organization admin. '
                    "You'll be added as a player.",
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Join code',
                      hintText: 'AB3XQZ9K',
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Join code is required' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Join organization'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
