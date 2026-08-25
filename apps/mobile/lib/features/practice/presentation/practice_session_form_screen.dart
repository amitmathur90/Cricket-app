import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../auth/application/session_controller.dart';
import '../../coaches/application/coaches_providers.dart';
import '../../coaches/data/models/coach.dart';
import '../application/practice_providers.dart';
import '../data/models/practice_session.dart';

/// Create/Edit practice session — team comes from the route (not
/// user-selected, per the spec), coach is picked from the org's coach list,
/// date+time combine into `scheduledAt`, and the remaining fields
/// (venue/duration/notes) mirror `CreatePracticeSessionDto`/
/// `UpdatePracticeSessionDto` exactly. Same "one route, `extra` decides
/// create-vs-edit" pattern as MatchFormScreen.
class PracticeSessionFormScreen extends ConsumerStatefulWidget {
  const PracticeSessionFormScreen({super.key, required this.teamId, this.existing});

  final String teamId;

  /// When non-null, the form opens pre-filled with this session's data and
  /// submits via PATCH instead of POST.
  final PracticeSession? existing;

  @override
  ConsumerState<PracticeSessionFormScreen> createState() => _PracticeSessionFormScreenState();
}

class _PracticeSessionFormScreenState extends ConsumerState<PracticeSessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _venueController = TextEditingController();
  final _durationController = TextEditingController();
  final _notesController = TextEditingController();

  PracticeType _practiceType = PracticeType.netPractice;
  String? _coachId;
  DateTime? _scheduledAt;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _practiceType = existing.practiceType;
      _coachId = existing.coachId;
      _scheduledAt = existing.scheduledAt.toLocal();
      _venueController.text = existing.venueName ?? '';
      _durationController.text = existing.durationMinutes?.toString() ?? '';
      _notesController.text = existing.notes ?? '';
    }
  }

  @override
  void dispose() {
    _venueController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    if (_scheduledAt == null) {
      _showSnack('Please pick a date & time');
      return;
    }

    final organizationId = ref.read(sessionControllerProvider).activeOrgId;
    if (organizationId == null) return;

    final durationText = _durationController.text.trim();
    final duration = durationText.isEmpty ? null : int.tryParse(durationText);

    setState(() => _submitting = true);
    try {
      final repo = ref.read(practiceSessionsRepositoryProvider);
      if (_isEditing) {
        final sessionId = widget.existing!.id;
        await repo.update(
          organizationId,
          widget.teamId,
          sessionId,
          practiceType: _practiceType,
          scheduledAt: _scheduledAt!,
          coachId: _coachId,
          venueName: _emptyToNull(_venueController.text),
          durationMinutes: duration,
          notes: _emptyToNull(_notesController.text),
        );
        ref.invalidate(
          practiceSessionDetailProvider((teamId: widget.teamId, sessionId: sessionId)),
        );
      } else {
        await repo.create(
          organizationId,
          widget.teamId,
          practiceType: _practiceType,
          scheduledAt: _scheduledAt!,
          coachId: _coachId,
          venueName: _emptyToNull(_venueController.text),
          durationMinutes: duration,
          notes: _emptyToNull(_notesController.text),
        );
      }
      ref.invalidate(practiceSessionsListProvider);
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
    final coachesAsync = ref.watch(coachesListProvider);
    final dateTimeFormat = DateFormat('EEE, MMM d, yyyy · h:mm a');

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit practice session' : 'New practice session')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<PracticeType>(
                initialValue: _practiceType,
                decoration: const InputDecoration(labelText: 'Practice type'),
                items: PracticeType.values
                    .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _practiceType = value);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date & time'),
                subtitle: Text(
                  _scheduledAt == null ? 'Required — tap to set' : dateTimeFormat.format(_scheduledAt!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 8),
              coachesAsync.when(
                data: (coaches) => _CoachField(
                  coaches: coaches,
                  value: _coachId,
                  onChanged: (value) => setState(() => _coachId = value),
                  onAddCoach: () async {
                    await context.push(coachesListPath);
                    ref.invalidate(coachesListProvider);
                  },
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (error, stackTrace) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error is ApiException ? error.message : 'Failed to load coaches',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _venueController,
                decoration: const InputDecoration(labelText: 'Venue (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(labelText: 'Duration in minutes (optional)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Create session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachField extends StatelessWidget {
  const _CoachField({
    required this.coaches,
    required this.value,
    required this.onChanged,
    required this.onAddCoach,
  });

  final List<Coach> coaches;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onAddCoach;

  @override
  Widget build(BuildContext context) {
    if (coaches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'No coaches yet — add one to assign this session.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(onPressed: onAddCoach, child: const Text('Add coach')),
          ],
        ),
      );
    }

    // Guard against a stale selection whose id is no longer in the resolved
    // list (e.g. the coach was deleted since this form was opened).
    final ids = coaches.map((c) => c.id).toSet();
    final selected = (value != null && ids.contains(value)) ? value : null;

    return DropdownButtonFormField<String?>(
      initialValue: selected,
      decoration: const InputDecoration(labelText: 'Coach (optional)'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('No coach assigned')),
        for (final coach in coaches)
          DropdownMenuItem<String?>(value: coach.id, child: Text(coach.fullName)),
      ],
      onChanged: onChanged,
    );
  }
}
