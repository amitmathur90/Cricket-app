import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/scoring_lineup.dart';
import '../../data/models/scoring_models.dart';

class WicketDialogResult {
  const WicketDialogResult({
    required this.dismissalType,
    required this.runsCompleted,
    this.dismissedTeamPlayerId,
    this.fielderTeamPlayerId,
    this.nextBatterTeamPlayerId,
  });

  final ScoringDismissalType dismissalType;

  /// Runs physically run by the batters before the dismissal (almost always
  /// 0, but a run out can happen after 1+ completed runs).
  final int runsCompleted;

  /// Only meaningful (and only sent to the backend) for `runOut` — every
  /// other dismissal type always dismisses the striker, inferred
  /// server-side.
  final String? dismissedTeamPlayerId;
  final String? fielderTeamPlayerId;

  /// Null only when this is the innings' 10th wicket.
  final String? nextBatterTeamPlayerId;
}

/// Collects a wicket's details: dismissal type, fielder (for catch/run-out/
/// stumped), which batter was dismissed (run-out only — every other type
/// always dismisses the striker), runs completed before the dismissal, and
/// the incoming batter (unless this is the innings-ending 10th wicket).
///
/// Mirrors every validation rule `ScoringRealtimeService.recordBall`
/// enforces server-side (see that method's wicket-flow block) so the
/// scorer is guided into a valid submission rather than trial-and-error
/// against server error messages — the backend still re-validates
/// everything as the actual source of truth.
Future<WicketDialogResult?> showWicketDialog(
  BuildContext context, {
  required String strikerName,
  required String? strikerId,
  required String nonStrikerName,
  required String? nonStrikerId,
  required List<ScoringLineupPlayer> fieldingXi,
  required List<ScoringLineupPlayer> nextBatterOptions,
  required bool requireNextBatter,
}) {
  return showDialog<WicketDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _WicketDialog(
      strikerName: strikerName,
      strikerId: strikerId,
      nonStrikerName: nonStrikerName,
      nonStrikerId: nonStrikerId,
      fieldingXi: fieldingXi,
      nextBatterOptions: nextBatterOptions,
      requireNextBatter: requireNextBatter,
    ),
  );
}

class _WicketDialog extends StatefulWidget {
  const _WicketDialog({
    required this.strikerName,
    required this.strikerId,
    required this.nonStrikerName,
    required this.nonStrikerId,
    required this.fieldingXi,
    required this.nextBatterOptions,
    required this.requireNextBatter,
  });

  final String strikerName;
  final String? strikerId;
  final String nonStrikerName;
  final String? nonStrikerId;
  final List<ScoringLineupPlayer> fieldingXi;
  final List<ScoringLineupPlayer> nextBatterOptions;
  final bool requireNextBatter;

  @override
  State<_WicketDialog> createState() => _WicketDialogState();
}

class _WicketDialogState extends State<_WicketDialog> {
  ScoringDismissalType _dismissalType = ScoringDismissalType.bowled;
  String? _fielderId;
  String? _dismissedId; // run-out only
  String? _nextBatterId;
  int _runsCompleted = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _dismissedId = widget.strikerId;
  }

  void _submit() {
    if (_dismissalType == ScoringDismissalType.runOut && _dismissedId == null) {
      setState(() => _error = 'Select who was run out');
      return;
    }
    if (widget.requireNextBatter && _nextBatterId == null) {
      setState(() => _error = 'Select the incoming batter');
      return;
    }
    Navigator.of(context).pop(
      WicketDialogResult(
        dismissalType: _dismissalType,
        runsCompleted: _runsCompleted,
        dismissedTeamPlayerId: _dismissalType == ScoringDismissalType.runOut ? _dismissedId : null,
        fielderTeamPlayerId: _fielderId,
        nextBatterTeamPlayerId: widget.requireNextBatter ? _nextBatterId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFielder = _dismissalType.usuallyHasFielder;

    return AlertDialog(
      title: const Text('Wicket'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dismissal type', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in ScoringDismissalType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _dismissalType == type,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      side: BorderSide(color: _dismissalType == type ? AppColors.primary : AppColors.border),
                      labelStyle: TextStyle(
                        color: _dismissalType == type ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: _dismissalType == type ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (value) {
                        if (!value) return;
                        setState(() {
                          _dismissalType = type;
                          if (type != ScoringDismissalType.runOut) {
                            _dismissedId = widget.strikerId;
                          }
                          if (!type.usuallyHasFielder) {
                            _fielderId = null;
                          }
                        });
                      },
                    ),
                ],
              ),
              if (_dismissalType == ScoringDismissalType.runOut) ...[
                const SizedBox(height: 12),
                const Text('Who was run out?', style: TextStyle(fontWeight: FontWeight.w600)),
                RadioGroup<String?>(
                  groupValue: _dismissedId,
                  onChanged: (value) => setState(() => _dismissedId = value),
                  child: Column(
                    children: [
                      RadioListTile<String?>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${widget.strikerName} (striker)'),
                        value: widget.strikerId,
                      ),
                      RadioListTile<String?>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${widget.nonStrikerName} (non-striker)'),
                        value: widget.nonStrikerId,
                      ),
                    ],
                  ),
                ),
              ],
              if (showFielder) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _fielderId,
                  decoration: const InputDecoration(labelText: 'Fielder (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— None —')),
                    for (final p in widget.fieldingXi)
                      DropdownMenuItem<String?>(value: p.teamPlayerId, child: Text(p.fullName)),
                  ],
                  onChanged: (value) => setState(() => _fielderId = value),
                ),
              ],
              const SizedBox(height: 12),
              Text('Runs completed before the dismissal', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (var r = 0; r <= 3; r++)
                    ChoiceChip(
                      label: Text('$r'),
                      selected: _runsCompleted == r,
                      onSelected: (_) => setState(() => _runsCompleted = r),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.requireNextBatter)
                DropdownButtonFormField<String>(
                  initialValue: _nextBatterId,
                  decoration: const InputDecoration(labelText: 'Incoming batter'),
                  items: widget.nextBatterOptions
                      .map((p) => DropdownMenuItem(value: p.teamPlayerId, child: Text(p.fullName)))
                      .toList(),
                  onChanged: (value) => setState(() => _nextBatterId = value),
                )
              else
                const Text(
                  'This is the 10th wicket — the innings ends here, no incoming batter needed.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Confirm wicket')),
      ],
    );
  }
}
