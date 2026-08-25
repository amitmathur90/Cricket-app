import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../data/models/sponsor.dart';

class SponsorFormResult {
  const SponsorFormResult({
    required this.companyName,
    this.logoUrl,
    this.packageName,
    this.amount,
    this.contractStartDate,
    this.contractEndDate,
    required this.visibleOnWebsite,
    required this.visibleOnApp,
    required this.visibleOnMatchScreen,
    required this.visibleOnScoreboard,
    required this.visibleOnSocialMedia,
  });

  final String companyName;
  final String? logoUrl;
  final String? packageName;
  final String? amount;
  final String? contractStartDate;
  final String? contractEndDate;
  final bool visibleOnWebsite;
  final bool visibleOnApp;
  final bool visibleOnMatchScreen;
  final bool visibleOnScoreboard;
  final bool visibleOnSocialMedia;
}

/// Simple modal form matching `CreateSponsorDto`/`UpdateSponsorDto`
/// (apps/backend/src/modules/sponsors/dto) — companyName required,
/// logo/package/amount/contract dates optional, plus the 5 display-surface
/// visibility toggles. Same "one dialog, `existing` decides create-vs-edit"
/// pattern as CoachFormDialog, including its upload-tile pattern for the
/// (optional) sponsor logo.
Future<SponsorFormResult?> showSponsorFormDialog(
  BuildContext context,
  String organizationId, {
  Sponsor? existing,
}) {
  return showDialog<SponsorFormResult>(
    context: context,
    builder: (context) => _SponsorFormDialog(organizationId: organizationId, existing: existing),
  );
}

class _SponsorFormDialogState extends ConsumerState<_SponsorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _packageNameController = TextEditingController();
  final _amountController = TextEditingController();

  String? _logoUrl;
  bool _uploadingLogo = false;
  String? _uploadError;

  DateTime? _contractStartDate;
  DateTime? _contractEndDate;

  bool _visibleOnWebsite = false;
  bool _visibleOnApp = false;
  bool _visibleOnMatchScreen = false;
  bool _visibleOnScoreboard = false;
  bool _visibleOnSocialMedia = false;

  bool get _isEditing => widget.existing != null;

  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _companyNameController.text = existing.companyName;
      _packageNameController.text = existing.packageName ?? '';
      _amountController.text = existing.amount ?? '';
      _logoUrl = existing.logoUrl;
      _contractStartDate =
          existing.contractStartDate != null ? DateTime.tryParse(existing.contractStartDate!) : null;
      _contractEndDate =
          existing.contractEndDate != null ? DateTime.tryParse(existing.contractEndDate!) : null;
      _visibleOnWebsite = existing.visibleOnWebsite;
      _visibleOnApp = existing.visibleOnApp;
      _visibleOnMatchScreen = existing.visibleOnMatchScreen;
      _visibleOnScoreboard = existing.visibleOnScoreboard;
      _visibleOnSocialMedia = existing.visibleOnSocialMedia;
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _packageNameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadLogo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _uploadError = null;
      _uploadingLogo = true;
    });

    try {
      final url = await ref
          .read(uploadsRepositoryProvider)
          .upload(widget.organizationId, File(picked.path));
      if (!mounted) return;
      setState(() => _logoUrl = url);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = e.message);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _contractStartDate : _contractEndDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _contractStartDate = picked;
      } else {
        _contractEndDate = picked;
      }
    });
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      SponsorFormResult(
        companyName: _companyNameController.text.trim(),
        logoUrl: _logoUrl,
        packageName: _emptyToNull(_packageNameController.text),
        amount: _emptyToNull(_amountController.text),
        contractStartDate: _contractStartDate != null ? _dateFormat.format(_contractStartDate!) : null,
        contractEndDate: _contractEndDate != null ? _dateFormat.format(_contractEndDate!) : null,
        visibleOnWebsite: _visibleOnWebsite,
        visibleOnApp: _visibleOnApp,
        visibleOnMatchScreen: _visibleOnMatchScreen,
        visibleOnScoreboard: _visibleOnScoreboard,
        visibleOnSocialMedia: _visibleOnSocialMedia,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit sponsor' : 'Add sponsor'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(labelText: 'Company name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Company name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _packageNameController,
                  decoration: const InputDecoration(
                    labelText: 'Package (optional)',
                    hintText: 'e.g. Title Sponsor, Gold, Silver',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount (optional)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return num.tryParse(v.trim()) == null ? 'Enter a valid number' : null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contract start (optional)'),
                  subtitle: Text(
                    _contractStartDate == null ? 'Not set' : _dateFormat.format(_contractStartDate!),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_contractStartDate != null)
                        IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _contractStartDate = null),
                        ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                  onTap: () => _pickDate(isStart: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Contract end (optional)'),
                  subtitle: Text(
                    _contractEndDate == null ? 'Not set' : _dateFormat.format(_contractEndDate!),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_contractEndDate != null)
                        IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _contractEndDate = null),
                        ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                  onTap: () => _pickDate(isStart: false),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _uploadingLogo ? null : _pickAndUploadLogo,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (_uploadingLogo)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_logoUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              Env.mediaUrl(_logoUrl!),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          const Icon(Icons.upload_file),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _logoUrl != null ? 'Logo uploaded' : 'Upload logo (optional)',
                            style: TextStyle(color: _logoUrl != null ? Colors.green : null),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_uploadError != null) ...[
                  const SizedBox(height: 8),
                  Text(_uploadError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 8),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('Visible on', style: Theme.of(context).textTheme.labelLarge),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Website'),
                  value: _visibleOnWebsite,
                  onChanged: (v) => setState(() => _visibleOnWebsite = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('App'),
                  value: _visibleOnApp,
                  onChanged: (v) => setState(() => _visibleOnApp = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Match Screen'),
                  value: _visibleOnMatchScreen,
                  onChanged: (v) => setState(() => _visibleOnMatchScreen = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Scoreboard'),
                  value: _visibleOnScoreboard,
                  onChanged: (v) => setState(() => _visibleOnScoreboard = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Social Media'),
                  value: _visibleOnSocialMedia,
                  onChanged: (v) => setState(() => _visibleOnSocialMedia = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _uploadingLogo ? null : _submit,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

class _SponsorFormDialog extends ConsumerStatefulWidget {
  const _SponsorFormDialog({required this.organizationId, this.existing});

  final String organizationId;
  final Sponsor? existing;

  @override
  ConsumerState<_SponsorFormDialog> createState() => _SponsorFormDialogState();
}
