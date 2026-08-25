import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../data/models/player.dart';

class AddPlayerResult {
  const AddPlayerResult({
    required this.fullName,
    required this.role,
    required this.ageCategory,
    required this.previousStatsNotes,
    required this.photoUrl,
    required this.idDocumentUrl,
    this.battingStyle,
    this.bowlingStyle,
    this.basePrice,
  });

  final String fullName;
  final PlayerRole role;
  final String ageCategory;
  final String previousStatsNotes;
  final String photoUrl;
  final String idDocumentUrl;
  final String? battingStyle;
  final String? bowlingStyle;
  final num? basePrice;
}

/// Modal form matching `CreatePlayerDto` in
/// apps/backend/src/modules/players/dto/create-player.dto.ts. Photo and ID
/// document are required and captured via the device camera/gallery,
/// uploaded immediately to `POST .../uploads` on selection.
Future<AddPlayerResult?> showAddPlayerDialog(BuildContext context, String organizationId) {
  return showDialog<AddPlayerResult>(
    context: context,
    builder: (context) => _AddPlayerDialog(organizationId: organizationId),
  );
}

class _AddPlayerDialog extends ConsumerStatefulWidget {
  const _AddPlayerDialog({required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<_AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends ConsumerState<_AddPlayerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _battingStyleController = TextEditingController();
  final _bowlingStyleController = TextEditingController();
  final _ageCategoryController = TextEditingController();
  final _previousStatsController = TextEditingController();
  final _basePriceController = TextEditingController();

  PlayerRole _role = PlayerRole.batsman;

  String? _photoUrl;
  String? _idDocumentUrl;
  bool _uploadingPhoto = false;
  bool _uploadingIdDocument = false;
  String? _uploadError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _battingStyleController.dispose();
    _bowlingStyleController.dispose();
    _ageCategoryController.dispose();
    _previousStatsController.dispose();
    _basePriceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload({required bool isPhoto}) async {
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
      if (isPhoto) {
        _uploadingPhoto = true;
      } else {
        _uploadingIdDocument = true;
      }
    });

    try {
      final url = await ref
          .read(uploadsRepositoryProvider)
          .upload(widget.organizationId, File(picked.path));
      if (!mounted) return;
      setState(() {
        if (isPhoto) {
          _photoUrl = url;
        } else {
          _idDocumentUrl = url;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _uploadingIdDocument = false;
        });
      }
    }
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_photoUrl == null || _idDocumentUrl == null) {
      setState(() => _uploadError = 'Please upload both a photo and an ID document');
      return;
    }
    final basePriceText = _basePriceController.text.trim();
    Navigator.of(context).pop(
      AddPlayerResult(
        fullName: _fullNameController.text.trim(),
        role: _role,
        ageCategory: _ageCategoryController.text.trim(),
        previousStatsNotes: _previousStatsController.text.trim(),
        photoUrl: _photoUrl!,
        idDocumentUrl: _idDocumentUrl!,
        battingStyle: _emptyToNull(_battingStyleController.text),
        bowlingStyle: _emptyToNull(_bowlingStyleController.text),
        basePrice: basePriceText.isEmpty ? null : num.tryParse(basePriceText),
      ),
    );
  }

  Widget _uploadTile({
    required String label,
    required String? url,
    required bool uploading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (uploading)
              const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else if (url != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(Env.mediaUrl(url), width: 40, height: 40, fit: BoxFit.cover),
              )
            else
              const Icon(Icons.upload_file),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                url != null ? '$label uploaded' : 'Upload $label *',
                style: TextStyle(color: url != null ? Colors.green : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add player'),
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
                DropdownButtonFormField<PlayerRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Playing role'),
                  items: PlayerRole.values
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageCategoryController,
                  decoration: const InputDecoration(
                    labelText: 'Age category',
                    hintText: 'e.g. U16, U19, Senior, Open',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Age category is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _battingStyleController,
                  decoration: const InputDecoration(labelText: 'Batting style (optional)'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bowlingStyleController,
                  decoration: const InputDecoration(labelText: 'Bowling style (optional)'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _previousStatsController,
                  decoration: const InputDecoration(
                    labelText: 'Previous teams / statistics',
                    hintText: 'Prior experience, notable numbers, past clubs...',
                  ),
                  maxLines: 3,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Previous statistics are required' : null,
                ),
                const SizedBox(height: 16),
                _uploadTile(
                  label: 'photo',
                  url: _photoUrl,
                  uploading: _uploadingPhoto,
                  onTap: () => _pickAndUpload(isPhoto: true),
                ),
                const SizedBox(height: 12),
                _uploadTile(
                  label: 'ID document',
                  url: _idDocumentUrl,
                  uploading: _uploadingIdDocument,
                  onTap: () => _pickAndUpload(isPhoto: false),
                ),
                if (_uploadError != null) ...[
                  const SizedBox(height: 8),
                  Text(_uploadError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _basePriceController,
                  decoration: const InputDecoration(labelText: 'Auction base price (optional)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: (_uploadingPhoto || _uploadingIdDocument) ? null : _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
