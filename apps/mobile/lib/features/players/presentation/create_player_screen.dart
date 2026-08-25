import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../application/players_providers.dart';
import '../data/models/player.dart';

/// Maximum number of "other supporting documents" the wizard lets a user
/// attach client-side. The backend caps `otherDocumentUrls` at 20
/// (`@ArrayMaxSize(20)` on `CreatePlayerDto`) — 10 is a friendlier UI cap
/// well under that limit.
const _maxOtherDocuments = 10;

/// One slot in the repeatable "other documents" list — zero-to-many, so
/// each slot tracks its own upload/URL state independently.
class _OtherDocumentSlot {
  String? url;
  bool uploading = false;
}

/// 5-step "Register player" wizard (Personal Information, Cricket
/// Information, Documents, Availability, Submit), replacing the old
/// single-form `AddPlayerDialog`.
///
/// Design decision — collect-then-submit-once, mirroring
/// `CreateTournamentScreen`: all 5 steps are held in client-side state and
/// only sent to the API once, on the final "Register player" tap. This is a
/// single `POST .../players` with the full `CreatePlayerDto` payload,
/// followed by a `PATCH .../players/:id` to set the granular
/// `isAvailableFor*` flags only when the user turned one off (those aren't
/// part of `CreatePlayerDto` — they're update-only server-side, per its
/// doc comment — so they can't ride along with the create call, but the
/// server-side default of `true` for all three means the second call is
/// only needed when a toggle actually changed).
class CreatePlayerScreen extends ConsumerStatefulWidget {
  const CreatePlayerScreen({super.key});

  @override
  ConsumerState<CreatePlayerScreen> createState() => _CreatePlayerScreenState();
}

class _CreatePlayerScreenState extends ConsumerState<CreatePlayerScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static const _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  /// One Form per step that has text fields to validate — step 0 (Personal
  /// information) and step 1 (Cricket information). Step 2 (Documents) is
  /// validated separately (upload-tile presence, not text fields); steps 3
  /// (Availability) and 4 (Submit/review) have nothing to validate.
  final _formKeys = List.generate(2, (_) => GlobalKey<FormState>());

  int _currentStep = 0;
  bool _submitting = false;

  // --- Step 1: Personal information ---
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  // --- Step 2: Cricket information ---
  PlayerRole _role = PlayerRole.batsman;
  final _ageCategoryController = TextEditingController();
  final _battingStyleController = TextEditingController();
  final _bowlingStyleController = TextEditingController();
  final _experienceController = TextEditingController();
  final _preferredPositionController = TextEditingController();
  final _previousStatsController = TextEditingController();

  // --- Step 3: Documents ---
  // Photograph is already captured in step 1 (personal information) — not
  // repeated here, since `photoUrl` is a single field on the player, not a
  // "document" in the DTO's document group.
  String? _idDocumentUrl;
  bool _uploadingIdDocument = false;
  String? _addressProofUrl;
  bool _uploadingAddressProof = false;
  final List<_OtherDocumentSlot> _otherDocuments = [];

  // --- Step 4: Availability ---
  bool _isAvailableForTournaments = true;
  bool _isAvailableForMatches = true;
  bool _isAvailableForPractice = true;

  String? _uploadError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _ageCategoryController.dispose();
    _battingStyleController.dispose();
    _bowlingStyleController.dispose();
    _experienceController.dispose();
    _preferredPositionController.dispose();
    _previousStatsController.dispose();
    super.dispose();
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _dob = picked);
  }

  Future<String?> _pickAndUploadFile() async {
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
    if (source == null) return null;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return null;

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return null;

    return ref.read(uploadsRepositoryProvider).upload(organizationId, File(picked.path));
  }

  Future<void> _pickAndUploadPhoto() async {
    setState(() {
      _uploadError = null;
      _uploadingPhoto = true;
    });
    try {
      final url = await _pickAndUploadFile();
      if (!mounted) return;
      if (url != null) setState(() => _photoUrl = url);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = e.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickAndUploadIdDocument() async {
    setState(() {
      _uploadError = null;
      _uploadingIdDocument = true;
    });
    try {
      final url = await _pickAndUploadFile();
      if (!mounted) return;
      if (url != null) setState(() => _idDocumentUrl = url);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = e.message);
    } finally {
      if (mounted) setState(() => _uploadingIdDocument = false);
    }
  }

  Future<void> _pickAndUploadAddressProof() async {
    setState(() {
      _uploadError = null;
      _uploadingAddressProof = true;
    });
    try {
      final url = await _pickAndUploadFile();
      if (!mounted) return;
      if (url != null) setState(() => _addressProofUrl = url);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = e.message);
    } finally {
      if (mounted) setState(() => _uploadingAddressProof = false);
    }
  }

  void _addOtherDocumentSlot() {
    if (_otherDocuments.length >= _maxOtherDocuments) {
      _showSnack('You can attach up to $_maxOtherDocuments other documents');
      return;
    }
    setState(() => _otherDocuments.add(_OtherDocumentSlot()));
  }

  void _removeOtherDocumentSlot(int index) {
    setState(() => _otherDocuments.removeAt(index));
  }

  Future<void> _pickAndUploadOtherDocument(int index) async {
    setState(() {
      _uploadError = null;
      _otherDocuments[index].uploading = true;
    });
    try {
      final url = await _pickAndUploadFile();
      if (!mounted) return;
      if (url != null) setState(() => _otherDocuments[index].url = url);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploadError = e.message);
    } finally {
      if (mounted) setState(() => _otherDocuments[index].uploading = false);
    }
  }

  bool _validateStep(int step) {
    if (step < _formKeys.length && !(_formKeys[step].currentState?.validate() ?? true)) {
      return false;
    }
    switch (step) {
      case 0:
        if (_photoUrl == null) {
          _showSnack('Please upload a player photo');
          return false;
        }
        return true;
      case 2:
        if (_idDocumentUrl == null) {
          _showSnack('Please upload an ID document');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _handleStepContinue() {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep < 4) {
      setState(() => _currentStep += 1);
    }
  }

  void _handleStepCancel() {
    if (_currentStep == 0) {
      context.pop();
      return;
    }
    setState(() => _currentStep -= 1);
  }

  Future<void> _submit() async {
    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;
    // Re-validate every step in case the user jumped back and left something
    // invalid before landing back on the review step.
    for (var step = 0; step < 4; step++) {
      if (!_validateStep(step)) {
        setState(() => _currentStep = step);
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(playersRepositoryProvider);
      final otherDocumentUrls = _otherDocuments
          .map((slot) => slot.url)
          .whereType<String>()
          .toList();

      final created = await repo.create(
        organizationId,
        fullName: _fullNameController.text.trim(),
        role: _role,
        ageCategory: _ageCategoryController.text.trim(),
        previousStatsNotes: _previousStatsController.text.trim(),
        photoUrl: _photoUrl!,
        idDocumentUrl: _idDocumentUrl!,
        dob: _dob == null ? null : _dateFormat.format(_dob!),
        gender: _gender,
        phone: _emptyToNull(_phoneController.text),
        email: _emptyToNull(_emailController.text),
        address: _emptyToNull(_addressController.text),
        battingStyle: _emptyToNull(_battingStyleController.text),
        bowlingStyle: _emptyToNull(_bowlingStyleController.text),
        experience: _emptyToNull(_experienceController.text),
        preferredPosition: _emptyToNull(_preferredPositionController.text),
        addressProofUrl: _addressProofUrl,
        otherDocumentUrls: otherDocumentUrls.isEmpty ? null : otherDocumentUrls,
      );

      // The granular availability flags default to `true` server-side and
      // aren't part of CreatePlayerDto — only PATCH them if the user
      // actually turned one off, to avoid a pointless extra call.
      if (!_isAvailableForTournaments || !_isAvailableForMatches || !_isAvailableForPractice) {
        await repo.updateAvailabilityFlags(
          organizationId,
          created.id,
          isAvailableForTournaments: _isAvailableForTournaments,
          isAvailableForMatches: _isAvailableForMatches,
          isAvailableForPractice: _isAvailableForPractice,
        );
      }

      ref.invalidate(playersListProvider);
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register player')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _submitting ? null : _handleStepContinue,
        onStepCancel: _submitting ? null : _handleStepCancel,
        onStepTapped: _submitting
            ? null
            : (step) {
                if (step < _currentStep) setState(() => _currentStep = step);
              },
        controlsBuilder: (context, details) {
          if (_currentStep == 4) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _submitting ? null : details.onStepCancel,
                    child: const Text('Back'),
                  ),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Register player'),
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep > 0)
                  OutlinedButton(onPressed: details.onStepCancel, child: const Text('Back')),
                const Spacer(),
                FilledButton(onPressed: details.onStepContinue, child: const Text('Continue')),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Personal information'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildPersonalInfoStep(),
          ),
          Step(
            title: const Text('Cricket information'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildCricketInfoStep(),
          ),
          Step(
            title: const Text('Documents'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildDocumentsStep(),
          ),
          Step(
            title: const Text('Availability'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: _buildAvailabilityStep(),
          ),
          Step(
            title: const Text('Submit'),
            isActive: _currentStep >= 4,
            state: StepState.indexed,
            content: _buildReviewStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _uploadTile(
            label: 'photo',
            url: _photoUrl,
            uploading: _uploadingPhoto,
            required: true,
            onTap: _pickAndUploadPhoto,
          ),
          if (_uploadError != null) ...[
            const SizedBox(height: 8),
            Text(_uploadError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(labelText: 'Full name *'),
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of birth (optional)'),
            subtitle: Text(_dob == null ? 'Not set' : _dateFormat.format(_dob!)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDob,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender (optional)'),
            items: _genderOptions
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (value) => setState(() => _gender = value),
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
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return _emailPattern.hasMatch(t) ? null : 'Enter a valid email address';
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Address (optional)'),
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildCricketInfoStep() {
    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<PlayerRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Playing role *'),
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
              labelText: 'Age category *',
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
            controller: _experienceController,
            decoration: const InputDecoration(
              labelText: 'Experience (optional)',
              hintText: 'e.g. 5 years club cricket',
            ),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _preferredPositionController,
            decoration: const InputDecoration(
              labelText: 'Preferred position (optional)',
              hintText: 'e.g. Opening batsman / slip fielder',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _previousStatsController,
            decoration: const InputDecoration(
              labelText: 'Previous teams / statistics *',
              hintText: 'Prior experience, notable numbers, past clubs...',
            ),
            minLines: 2,
            maxLines: 4,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Previous teams / statistics are required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Photograph is captured in step 1 (Personal information) — see the
        // comment on `_idDocumentUrl` above; it isn't duplicated here.
        _uploadTile(
          label: 'ID document',
          url: _idDocumentUrl,
          uploading: _uploadingIdDocument,
          required: true,
          onTap: _pickAndUploadIdDocument,
        ),
        const SizedBox(height: 12),
        _uploadTile(
          label: 'address proof',
          url: _addressProofUrl,
          uploading: _uploadingAddressProof,
          required: false,
          onTap: _pickAndUploadAddressProof,
        ),
        if (_uploadError != null) ...[
          const SizedBox(height: 8),
          Text(_uploadError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        Text('Other documents (optional)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (var i = 0; i < _otherDocuments.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: _uploadTile(
                  label: 'document ${i + 1}',
                  url: _otherDocuments[i].url,
                  uploading: _otherDocuments[i].uploading,
                  required: false,
                  onTap: () => _pickAndUploadOtherDocument(i),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Remove',
                onPressed: () => _removeOtherDocumentSlot(i),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_otherDocuments.length < _maxOtherDocuments)
          OutlinedButton.icon(
            onPressed: _addOtherDocumentSlot,
            icon: const Icon(Icons.add),
            label: const Text('Add another document'),
          ),
      ],
    );
  }

  Widget _buildAvailabilityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'These are separate from the single "mark unavailable" toggle in the '
          'player list — they let the player be picked (or not) for specific '
          'kinds of activity.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Available for tournaments'),
          value: _isAvailableForTournaments,
          onChanged: (value) => setState(() => _isAvailableForTournaments = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Available for matches'),
          value: _isAvailableForMatches,
          onChanged: (value) => setState(() => _isAvailableForMatches = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Available for practice'),
          value: _isAvailableForPractice,
          onChanged: (value) => setState(() => _isAvailableForPractice = value),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final rows = <Widget?>[
      _reviewRow('Full name', _fullNameController.text),
      _reviewRow('Photo', _photoUrl != null ? 'Uploaded' : null),
      _reviewRow('Date of birth', _dob == null ? null : _dateFormat.format(_dob!)),
      _reviewRow('Gender', _gender),
      _reviewRow('Phone', _phoneController.text),
      _reviewRow('Email', _emailController.text),
      _reviewRow('Address', _addressController.text),
      const Divider(),
      _reviewRow('Playing role', _role.label),
      _reviewRow('Age category', _ageCategoryController.text),
      _reviewRow('Batting style', _battingStyleController.text),
      _reviewRow('Bowling style', _bowlingStyleController.text),
      _reviewRow('Experience', _experienceController.text),
      _reviewRow('Preferred position', _preferredPositionController.text),
      _reviewRow('Previous teams / statistics', _previousStatsController.text),
      const Divider(),
      _reviewRow('ID document', _idDocumentUrl != null ? 'Uploaded' : null),
      _reviewRow('Address proof', _addressProofUrl != null ? 'Uploaded' : null),
      _reviewRow(
        'Other documents',
        _otherDocuments.isEmpty
            ? null
            : '${_otherDocuments.where((s) => s.url != null).length} uploaded',
      ),
      const Divider(),
      _reviewRow('Available for tournaments', _isAvailableForTournaments ? 'Yes' : 'No'),
      _reviewRow('Available for matches', _isAvailableForMatches ? 'Yes' : 'No'),
      _reviewRow('Available for practice', _isAvailableForPractice ? 'Yes' : 'No'),
    ].whereType<Widget>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review the details below, then register the player.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ...rows,
      ],
    );
  }

  Widget? _reviewRow(String label, String? value) {
    final display = (value == null || value.trim().isEmpty) ? null : value.trim();
    if (display == null) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(display)),
        ],
      ),
    );
  }

  Widget _uploadTile({
    required String label,
    required String? url,
    required bool uploading,
    required bool required,
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
              const SizedBox(height: 40, width: 40, child: CircularProgressIndicator(strokeWidth: 2))
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
                url != null ? '$label uploaded' : 'Upload $label${required ? ' *' : ' (optional)'}',
                style: TextStyle(color: url != null ? Colors.green : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
