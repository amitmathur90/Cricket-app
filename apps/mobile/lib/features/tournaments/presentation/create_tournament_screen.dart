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
import '../application/tournaments_providers.dart';
import '../data/models/tournament.dart';

/// 5-step "Create tournament" wizard (Basic Information, Tournament Details,
/// Rules, Registration, Publish), also doubling as the "Edit tournament"
/// flow when [existing] is supplied.
///
/// Design decision — collect-then-submit-once: all 5 steps are held in
/// client-side state and only sent to the API once, when the user taps
/// "Save as draft" or "Publish" on the final step (a single `POST
/// .../tournaments` for a new tournament, `PATCH .../tournaments/:id` for an
/// edit, optionally followed by a `PATCH` setting `status: upcoming` for
/// "Publish"). This was chosen over progressively PATCHing a draft
/// tournament after step 2, per the spec's guidance: it's simpler and
/// avoids littering the tournament list with abandoned partial drafts if
/// the user quits mid-wizard — logo upload doesn't need a tournament id
/// either (uploads are org-scoped), so there's no plumbing reason to create
/// early.
class CreateTournamentScreen extends ConsumerStatefulWidget {
  const CreateTournamentScreen({super.key, this.existing});

  /// When non-null, the wizard opens pre-filled with this tournament's data
  /// and submits via PATCH instead of POST.
  final Tournament? existing;

  @override
  ConsumerState<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends ConsumerState<CreateTournamentScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// One Form per step that has fields to validate (steps 0-3 — step 4 is a
  /// read-only review, nothing to validate).
  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());

  int _currentStep = 0;
  bool _submitting = false;

  // --- Step 1: Basic information ---
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _organizerNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  String? _logoUrl;
  bool _uploadingLogo = false;

  // --- Step 2: Tournament details ---
  TournamentFormat _format = TournamentFormat.t20;
  DateTime? _startDate;
  DateTime? _endDate;
  final _locationController = TextEditingController();
  final _numberOfTeamsController = TextEditingController();
  final _maxPlayersPerTeamController = TextEditingController();
  // Not part of the spec's 5-step field list, but was a field on the
  // dialog this wizard replaces — kept here rather than silently dropped.
  bool _auctionEnabled = false;

  // --- Step 3: Rules ---
  final _tournamentRulesController = TextEditingController();
  final _matchRulesController = TextEditingController();
  final _pointsSystemController = TextEditingController();
  final _tieBreakerRulesController = TextEditingController();

  // --- Step 4: Registration ---
  DateTime? _registrationOpensAt;
  DateTime? _registrationClosesAt;
  final _playerRegistrationFeeController = TextEditingController();
  final _teamRegistrationFeeController = TextEditingController();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _descriptionController.text = existing.description ?? '';
      _organizerNameController.text = existing.organizerName ?? '';
      _contactEmailController.text = existing.contactEmail ?? '';
      _contactPhoneController.text = existing.contactPhone ?? '';
      _logoUrl = existing.logoUrl;
      _format = existing.format;
      _startDate = DateTime.tryParse(existing.startDate);
      _endDate = DateTime.tryParse(existing.endDate);
      _locationController.text = existing.location ?? '';
      _numberOfTeamsController.text = existing.numberOfTeams?.toString() ?? '';
      _maxPlayersPerTeamController.text = existing.maxPlayersPerTeam?.toString() ?? '';
      _auctionEnabled = existing.auctionEnabled;
      _tournamentRulesController.text = existing.tournamentRules ?? '';
      _matchRulesController.text = existing.matchRules ?? '';
      _pointsSystemController.text = existing.pointsSystem ?? '';
      _tieBreakerRulesController.text = existing.tieBreakerRules ?? '';
      _registrationOpensAt =
          existing.registrationOpensAt == null ? null : DateTime.tryParse(existing.registrationOpensAt!);
      _registrationClosesAt = existing.registrationClosesAt == null
          ? null
          : DateTime.tryParse(existing.registrationClosesAt!);
      _playerRegistrationFeeController.text = existing.playerRegistrationFee ?? '';
      _teamRegistrationFeeController.text = existing.teamRegistrationFee ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _organizerNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _locationController.dispose();
    _numberOfTeamsController.dispose();
    _maxPlayersPerTeamController.dispose();
    _tournamentRulesController.dispose();
    _matchRulesController.dispose();
    _pointsSystemController.dispose();
    _tieBreakerRulesController.dispose();
    _playerRegistrationFeeController.dispose();
    _teamRegistrationFeeController.dispose();
    super.dispose();
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  int? _parseInt(String text) {
    final t = text.trim();
    return t.isEmpty ? null : int.tryParse(t);
  }

  num? _parseNum(String text) {
    final t = text.trim();
    return t.isEmpty ? null : num.tryParse(t);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _startDate : _endDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickRegistrationDate({required bool isOpens}) async {
    final now = DateTime.now();
    final initial = (isOpens ? _registrationOpensAt : _registrationClosesAt) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (isOpens) {
        _registrationOpensAt = picked;
      } else {
        _registrationClosesAt = picked;
      }
    });
  }

  Future<void> _pickAndUploadLogo() async {
    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;

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

    setState(() => _uploadingLogo = true);
    try {
      final url =
          await ref.read(uploadsRepositoryProvider).upload(organizationId, File(picked.path));
      if (!mounted) return;
      setState(() => _logoUrl = url);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  bool _validateStep(int step) {
    if (step < _formKeys.length && !(_formKeys[step].currentState?.validate() ?? true)) {
      return false;
    }
    switch (step) {
      case 1:
        if (_startDate == null || _endDate == null) {
          _showSnack('Pick a start and end date');
          return false;
        }
        if (_endDate!.isBefore(_startDate!)) {
          _showSnack('End date must be on or after the start date');
          return false;
        }
        return true;
      case 3:
        if (_registrationOpensAt != null &&
            _registrationClosesAt != null &&
            _registrationClosesAt!.isBefore(_registrationOpensAt!)) {
          _showSnack('Registration close date must be on or after the open date');
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

  Future<void> _submit({required bool publish}) async {
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
      final repo = ref.read(tournamentsRepositoryProvider);
      final startDate = _dateFormat.format(_startDate!);
      final endDate = _dateFormat.format(_endDate!);
      final registrationOpensAt =
          _registrationOpensAt == null ? null : _dateFormat.format(_registrationOpensAt!);
      final registrationClosesAt =
          _registrationClosesAt == null ? null : _dateFormat.format(_registrationClosesAt!);

      final Tournament saved;
      if (_isEditing) {
        saved = await repo.update(
          organizationId,
          widget.existing!.id,
          name: _nameController.text.trim(),
          format: _format,
          startDate: startDate,
          endDate: endDate,
          auctionEnabled: _auctionEnabled,
          logoUrl: _logoUrl,
          description: _emptyToNull(_descriptionController.text),
          organizerName: _emptyToNull(_organizerNameController.text),
          contactEmail: _emptyToNull(_contactEmailController.text),
          contactPhone: _emptyToNull(_contactPhoneController.text),
          location: _emptyToNull(_locationController.text),
          numberOfTeams: _parseInt(_numberOfTeamsController.text),
          maxPlayersPerTeam: _parseInt(_maxPlayersPerTeamController.text),
          tournamentRules: _emptyToNull(_tournamentRulesController.text),
          matchRules: _emptyToNull(_matchRulesController.text),
          pointsSystem: _emptyToNull(_pointsSystemController.text),
          tieBreakerRules: _emptyToNull(_tieBreakerRulesController.text),
          registrationOpensAt: registrationOpensAt,
          registrationClosesAt: registrationClosesAt,
          playerRegistrationFee: _parseNum(_playerRegistrationFeeController.text),
          teamRegistrationFee: _parseNum(_teamRegistrationFeeController.text),
        );
      } else {
        saved = await repo.create(
          organizationId,
          name: _nameController.text.trim(),
          format: _format,
          startDate: startDate,
          endDate: endDate,
          auctionEnabled: _auctionEnabled,
          logoUrl: _logoUrl,
          description: _emptyToNull(_descriptionController.text),
          organizerName: _emptyToNull(_organizerNameController.text),
          contactEmail: _emptyToNull(_contactEmailController.text),
          contactPhone: _emptyToNull(_contactPhoneController.text),
          location: _emptyToNull(_locationController.text),
          numberOfTeams: _parseInt(_numberOfTeamsController.text),
          maxPlayersPerTeam: _parseInt(_maxPlayersPerTeamController.text),
          tournamentRules: _emptyToNull(_tournamentRulesController.text),
          matchRules: _emptyToNull(_matchRulesController.text),
          pointsSystem: _emptyToNull(_pointsSystemController.text),
          tieBreakerRules: _emptyToNull(_tieBreakerRulesController.text),
          registrationOpensAt: registrationOpensAt,
          registrationClosesAt: registrationClosesAt,
          playerRegistrationFee: _parseNum(_playerRegistrationFeeController.text),
          teamRegistrationFee: _parseNum(_teamRegistrationFeeController.text),
        );
      }

      if (publish) {
        await repo.setStatus(organizationId, saved.id, 'upcoming');
      }

      ref.invalidate(tournamentsListProvider);
      if (_isEditing) ref.invalidate(tournamentDetailProvider(widget.existing!.id));
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit tournament' : 'Create tournament')),
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
                  OutlinedButton(
                    onPressed: _submitting ? null : () => _submit(publish: false),
                    child: const Text('Save as draft'),
                  ),
                  FilledButton(
                    onPressed: _submitting ? null : () => _submit(publish: true),
                    child: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Publish'),
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
            title: const Text('Basic information'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildBasicInfoStep(),
          ),
          Step(
            title: const Text('Tournament details'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildDetailsStep(),
          ),
          Step(
            title: const Text('Rules'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildRulesStep(),
          ),
          Step(
            title: const Text('Registration'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: _buildRegistrationStep(),
          ),
          Step(
            title: const Text('Publish'),
            isActive: _currentStep >= 4,
            state: StepState.indexed,
            content: _buildReviewStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Tournament name *'),
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          _logoUploadTile(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _organizerNameController,
            decoration: const InputDecoration(labelText: 'Organizer name (optional)'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contactEmailController,
            decoration: const InputDecoration(labelText: 'Contact email (optional)'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              return _emailPattern.hasMatch(t) ? null : 'Enter a valid email address';
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contactPhoneController,
            decoration: const InputDecoration(labelText: 'Contact phone (optional)'),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _logoUploadTile() {
    return InkWell(
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
              const SizedBox(height: 40, width: 40, child: CircularProgressIndicator(strokeWidth: 2))
            else if (_logoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
                _logoUrl != null ? 'Logo uploaded' : 'Upload tournament logo (optional)',
                style: TextStyle(color: _logoUrl != null ? Colors.green : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<TournamentFormat>(
            initialValue: _format,
            decoration: const InputDecoration(labelText: 'Format *'),
            items: TournamentFormat.values
                .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _format = value);
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start date *'),
            subtitle: Text(_startDate == null ? 'Not set' : _dateFormat.format(_startDate!)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(isStart: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End date *'),
            subtitle: Text(_endDate == null ? 'Not set' : _dateFormat.format(_endDate!)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickDate(isStart: false),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Location (optional)'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _numberOfTeamsController,
            decoration: const InputDecoration(labelText: 'Number of teams (optional)'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              final n = int.tryParse(t);
              return (n == null || n < 1) ? 'Enter a whole number of at least 1' : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _maxPlayersPerTeamController,
            decoration: const InputDecoration(labelText: 'Max players per team (optional)'),
            keyboardType: TextInputType.number,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              final n = int.tryParse(t);
              return (n == null || n < 1) ? 'Enter a whole number of at least 1' : null;
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auction enabled'),
            value: _auctionEnabled,
            onChanged: (value) => setState(() => _auctionEnabled = value),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesStep() {
    return Form(
      key: _formKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _tournamentRulesController,
            decoration: const InputDecoration(labelText: 'Tournament rules (optional)'),
            minLines: 2,
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _matchRulesController,
            decoration: const InputDecoration(labelText: 'Match rules (optional)'),
            minLines: 2,
            maxLines: 6,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pointsSystemController,
            decoration: const InputDecoration(
              labelText: 'Points system (optional)',
              hintText: 'e.g. 2 pts win, 1 pt tie, 0 pt loss',
            ),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _tieBreakerRulesController,
            decoration: const InputDecoration(labelText: 'Tie-breaker rules (optional)'),
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationStep() {
    return Form(
      key: _formKeys[3],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Registration opens (optional)'),
            subtitle: Text(
              _registrationOpensAt == null ? 'Not set' : _dateFormat.format(_registrationOpensAt!),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickRegistrationDate(isOpens: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Registration closes (optional)'),
            subtitle: Text(
              _registrationClosesAt == null ? 'Not set' : _dateFormat.format(_registrationClosesAt!),
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _pickRegistrationDate(isOpens: false),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _playerRegistrationFeeController,
            decoration: const InputDecoration(labelText: 'Player registration fee (optional)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              final n = num.tryParse(t);
              return (n == null || n < 0) ? 'Enter a non-negative amount' : null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _teamRegistrationFeeController,
            decoration: const InputDecoration(labelText: 'Team registration fee (optional)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return null;
              final n = num.tryParse(t);
              return (n == null || n < 0) ? 'Enter a non-negative amount' : null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final rows = <Widget?>[
      _reviewRow('Name', _nameController.text),
      _reviewRow('Description', _descriptionController.text),
      _reviewRow('Organizer', _organizerNameController.text),
      _reviewRow('Contact email', _contactEmailController.text),
      _reviewRow('Contact phone', _contactPhoneController.text),
      const Divider(),
      _reviewRow('Format', _format.label),
      _reviewRow('Dates', _startDate == null || _endDate == null
          ? null
          : '${_dateFormat.format(_startDate!)} to ${_dateFormat.format(_endDate!)}'),
      _reviewRow('Location', _locationController.text),
      _reviewRow('Number of teams', _numberOfTeamsController.text),
      _reviewRow('Max players per team', _maxPlayersPerTeamController.text),
      _reviewRow('Auction enabled', _auctionEnabled ? 'Yes' : 'No'),
      const Divider(),
      _reviewRow('Tournament rules', _tournamentRulesController.text),
      _reviewRow('Match rules', _matchRulesController.text),
      _reviewRow('Points system', _pointsSystemController.text),
      _reviewRow('Tie-breaker rules', _tieBreakerRulesController.text),
      const Divider(),
      _reviewRow(
        'Registration opens',
        _registrationOpensAt == null ? null : _dateFormat.format(_registrationOpensAt!),
      ),
      _reviewRow(
        'Registration closes',
        _registrationClosesAt == null ? null : _dateFormat.format(_registrationClosesAt!),
      ),
      _reviewRow('Player registration fee', _playerRegistrationFeeController.text),
      _reviewRow('Team registration fee', _teamRegistrationFeeController.text),
    ].whereType<Widget>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review the details below, then save as a draft or publish '
          '(publishing sets the tournament status to "upcoming").',
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
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(display)),
        ],
      ),
    );
  }
}
