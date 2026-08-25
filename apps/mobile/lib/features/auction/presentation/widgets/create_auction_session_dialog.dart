import 'package:flutter/material.dart';

/// Simple modal form matching `CreateAuctionSessionDto` in
/// apps/backend/src/modules/auction/dto/create-auction-session.dto.ts —
/// only `name` is required; the DTO's optional `bidIncrementRules` tiered
/// schedule is left out of this M1 UI (sessions created here use the
/// backend's default 5%-of-current-bid increment — see
/// auction-bid-increment.util.ts), matching this app's other "add" dialogs
/// (add_team_dialog.dart) which similarly expose only the required core
/// fields.
Future<String?> showCreateAuctionSessionDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _CreateAuctionSessionDialog(),
  );
}

class _CreateAuctionSessionDialog extends StatefulWidget {
  const _CreateAuctionSessionDialog();

  @override
  State<_CreateAuctionSessionDialog> createState() => _CreateAuctionSessionDialogState();
}

class _CreateAuctionSessionDialogState extends State<_CreateAuctionSessionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create auction session'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Session name',
            hintText: 'e.g. Main Auction — Day 1',
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
