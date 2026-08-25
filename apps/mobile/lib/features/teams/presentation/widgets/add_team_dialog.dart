import 'package:flutter/material.dart';

class AddTeamResult {
  const AddTeamResult({required this.name, this.shortCode});

  final String name;
  final String? shortCode;
}

/// Simple modal form matching `CreateTeamDto` in
/// apps/backend/src/modules/teams/dto/create-team.dto.ts (name required,
/// shortCode optional — logoUrl/ownerUserId omitted from M1's UI).
Future<AddTeamResult?> showAddTeamDialog(BuildContext context) {
  return showDialog<AddTeamResult>(
    context: context,
    builder: (context) => const _AddTeamDialog(),
  );
}

class _AddTeamDialog extends StatefulWidget {
  const _AddTeamDialog();

  @override
  State<_AddTeamDialog> createState() => _AddTeamDialogState();
}

class _AddTeamDialogState extends State<_AddTeamDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shortCodeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _shortCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      AddTeamResult(
        name: _nameController.text.trim(),
        shortCode: _shortCodeController.text.trim().isEmpty
            ? null
            : _shortCodeController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add team'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Team name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shortCodeController,
              decoration: const InputDecoration(labelText: 'Short code (optional)'),
              textCapitalization: TextCapitalization.characters,
              maxLength: 16,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
