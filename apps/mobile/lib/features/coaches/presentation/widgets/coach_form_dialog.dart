import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../data/models/coach.dart';

class CoachFormResult {
  const CoachFormResult({
    required this.fullName,
    this.phone,
    this.email,
    this.specialization,
    this.photoUrl,
  });

  final String fullName;
  final String? phone;
  final String? email;
  final String? specialization;
  final String? photoUrl;
}

/// Simple modal form matching `CreateCoachDto`/`UpdateCoachDto`
/// (apps/backend/src/modules/coaches/dto) — fullName required, everything
/// else optional. Same "one dialog, `existing` decides create-vs-edit"
/// pattern as AddTeamDialog, plus the upload-tile pattern from
/// AddPlayerDialog for the (optional, unlike the player's required photo)
/// coach photo.
Future<CoachFormResult?> showCoachFormDialog(
  BuildContext context,
  String organizationId, {
  Coach? existing,
}) {
  return showDialog<CoachFormResult>(
    context: context,
    builder: (context) => _CoachFormDialog(organizationId: organizationId, existing: existing),
  );
}

class _CoachFormDialog extends ConsumerStatefulWidget {
  const _CoachFormDialog({required this.organizationId, this.existing});

  final String organizationId;
  final Coach? existing;

  @override
  ConsumerState<_CoachFormDialog> createState() => _CoachFormDialogState();
}

class _CoachFormDialogState extends ConsumerState<_CoachFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _specializationController = TextEditingController();

  String? _photoUrl;
  bool _uploadingPhoto = false;
  String? _uploadError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _fullNameController.text = existing.fullName;
      _phoneController.text = existing.phone ?? '';
      _emailController.text = existing.email ?? '';
      _specializationController.text = existing.specialization ?? '';
      _photoUrl = existing.photoUrl;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
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
      _uploadingPhoto = true;
    });

    try {
      final url = await ref
          .read(uploadsRepositoryProvider)
          .upload(widget.organizationId, File(picked.path));
      if (!mounted) return;
      setState(() => _photoUrl = url);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = e.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CoachFormResult(
        fullName: _fullNameController.text.trim(),
        phone: _emptyToNull(_phoneController.text),
        email: _emptyToNull(_emailController.text),
        specialization: _emptyToNull(_specializationController.text),
        photoUrl: _photoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit coach' : 'Add coach'),
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
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone (optional)'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email (optional)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _specializationController,
                  decoration: const InputDecoration(
                    labelText: 'Specialization (optional)',
                    hintText: 'e.g. Batting coach, Fitness trainer',
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (_uploadingPhoto)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_photoUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              Env.mediaUrl(_photoUrl!),
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
                            _photoUrl != null ? 'Photo uploaded' : 'Upload photo (optional)',
                            style: TextStyle(color: _photoUrl != null ? Colors.green : null),
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
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _uploadingPhoto ? null : _submit,
          child: Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
