import 'package:flutter/material.dart';

import '../../data/models/scoring_models.dart';

/// A wide/no-ball/bye/leg-bye can still carry additional runs actually run
/// by the batters (see `RecordBallDto`'s doc comment) — this small dialog
/// asks for that count before the ball is submitted, rather than assuming
/// 0. Returns null if the scorer cancels.
Future<int?> showExtraRunsDialog(BuildContext context, ScoringExtraType type) {
  final prompt = switch (type) {
    ScoringExtraType.wide => 'Runs run in addition to the wide (0 if none)',
    ScoringExtraType.noBall => 'Runs off the bat on this no ball (0 if none)',
    ScoringExtraType.bye => 'Byes run',
    ScoringExtraType.legBye => 'Leg byes run',
    ScoringExtraType.penalty => 'Penalty runs',
  };

  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(type.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prompt),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var runs = 0; runs <= 6; runs++)
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(runs),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    shape: const CircleBorder(),
                  ),
                  child: Text('$runs'),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      ],
    ),
  );
}
