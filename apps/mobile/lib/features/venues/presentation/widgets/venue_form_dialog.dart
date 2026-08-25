import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../data/models/venue.dart';

class VenueFormResult {
  const VenueFormResult({
    required this.name,
    this.location,
    this.capacity,
    this.pitchType,
    this.facilities,
    this.photoUrl,
  });

  final String name;
  final String? location;
  final int? capacity;
  final String? pitchType;
  final String? facilities;
  final String? photoUrl;
}

/// Simple modal form matching `CreateVenueDto`/`UpdateVenueDto`
/// (apps/backend/src/modules/venues/dto) — name required, everything else
/// optional. Same "one dialog, `existing` decides create-vs-edit" pattern as
/// CoachFormDialog, including its upload-tile pattern for the (optional)
/// venue photo.
Future<VenueFormResult?> showVenueFormDialog(
  BuildContext context,
  String organizationId, {
  Venue? existing,
}) {
  return showDialog<VenueFormResult>(
    context: context,
    builder: (context) => _VenueFormDialog(organizationId: organizationId, existing: existing),
  );
}

class _VenueFormDialog extends ConsumerStatefulWidget {
  const _VenueFormDialog({required this.organizationId, this.existing});

  final String organizationId;
  final Venue? existing;

  @override
  ConsumerState<_VenueFormDialog> createState() => _VenueFormDialogState();
}

class _VenueFormDialogState extends ConsumerState<_VenueFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _pitchTypeController = TextEditingController();
  final _facilitiesController = TextEditingController();

  String? _photoUrl;
  bool _uploadingPhoto = false;
  String? _uploadError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _locationController.text = existing.location ?? '';
      _capacityController.text = existing.capacity?.toString() ?? '';
      _pitchTypeController.text = existing.pitchType ?? '';
      _facilitiesController.text = existing.facilities ?? '';
      _photoUrl = existing.photoUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _pitchTypeController.dispose();
    _facilitiesController.dispose();
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
    final capacityText = _capacityController.text.trim();
    Navigator.of(context).pop(
      VenueFormResult(
        name: _nameController.text.trim(),
        location: _emptyToNull(_locationController.text),
        capacity: capacityText.isEmpty ? null : int.tryParse(capacityText),
        pitchType: _emptyToNull(_pitchTypeController.text),
        facilities: _emptyToNull(_facilitiesController.text),
        photoUrl: _photoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit venue' : 'Add venue'),
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
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Venue name'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Location (optional)'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _capacityController,
                  decoration: const InputDecoration(labelText: 'Capacity (optional)'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return int.tryParse(v.trim()) == null ? 'Enter a whole number' : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pitchTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Pitch type (optional)',
                    hintText: 'e.g. Turf, Grass, Matting',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _facilitiesController,
                  decoration: const InputDecoration(
                    labelText: 'Facilities (optional)',
                    hintText: 'e.g. Parking, Floodlights, Pavilion',
                  ),
                  maxLines: 2,
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
