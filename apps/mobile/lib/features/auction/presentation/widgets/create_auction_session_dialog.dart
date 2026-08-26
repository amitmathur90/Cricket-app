import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/auction_repository.dart';

/// Opens the Auction Settings screen (a full-screen form, not a small modal
/// — there's enough here now that a compact `AlertDialog` no longer fits:
/// duration, purse, squad cap, and the tiered bid-increment schedule) and
/// resolves with a [CreateAuctionSessionInput] once the operator taps
/// "Create Session", or `null` if they back out. Mirrors
/// `CreateAuctionSessionDto` in
/// apps/backend/src/modules/auction/dto/create-auction-session.dto.ts field
/// for field — only `name` is required; everything else is optional and
/// omitted from the request when left unset (see
/// `CreateAuctionSessionInput.toJson`).
Future<CreateAuctionSessionInput?> showCreateAuctionSessionDialog(BuildContext context) {
  return Navigator.of(context).push<CreateAuctionSessionInput>(
    MaterialPageRoute(fullscreenDialog: true, builder: (context) => const AuctionSettingsScreen()),
  );
}

/// Preset options for the "Total Auction Duration" picker. This is purely
/// informational on the backend (`durationMinutes` — never enforced, see
/// the DTO's doc comment), so the picker's only job is to produce a minute
/// count or leave it unset; there is no per-lot timer to configure here at
/// all (see the read-only "Bid Timer" row below).
enum _DurationPreset { none, h1, h2, h3, h4, h5, h6, custom }

extension on _DurationPreset {
  String get label => switch (this) {
        _DurationPreset.none => 'No limit',
        _DurationPreset.h1 => '1h',
        _DurationPreset.h2 => '2h',
        _DurationPreset.h3 => '3h',
        _DurationPreset.h4 => '4h',
        _DurationPreset.h5 => '5h',
        _DurationPreset.h6 => '6h',
        _DurationPreset.custom => 'Custom',
      };

  int? get minutes => switch (this) {
        _DurationPreset.none => null,
        _DurationPreset.h1 => 60,
        _DurationPreset.h2 => 120,
        _DurationPreset.h3 => 180,
        _DurationPreset.h4 => 240,
        _DurationPreset.h5 => 300,
        _DurationPreset.h6 => 360,
        _DurationPreset.custom => null, // resolved from the custom field instead
      };
}

/// One editable row of the tiered bid-increment schedule. `upToController`
/// left blank means "no ceiling" (the catch-all top tier — matches
/// `BidIncrementRuleDto.upTo: null`, "Use null for the catch-all top tier").
class _TierRow {
  _TierRow({String? upTo, String? increment})
      : upToController = TextEditingController(text: upTo),
        incrementController = TextEditingController(text: increment);

  final TextEditingController upToController;
  final TextEditingController incrementController;

  void dispose() {
    upToController.dispose();
    incrementController.dispose();
  }
}

/// Full-screen "Auction Settings" form shown when creating a session —
/// collects everything `CreateAuctionSessionDto` accepts. Replaces the
/// earlier name-only dialog now that the backend supports session-level
/// duration/purse/squad-cap settings (see the class doc comment on
/// `CreateAuctionSessionInput`).
class AuctionSettingsScreen extends StatefulWidget {
  const AuctionSettingsScreen({super.key});

  @override
  State<AuctionSettingsScreen> createState() => _AuctionSettingsScreenState();
}

class _AuctionSettingsScreenState extends State<AuctionSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _defaultPointsController = TextEditingController();
  final _maxSquadController = TextEditingController();
  final _customDurationController = TextEditingController();

  _DurationPreset _durationPreset = _DurationPreset.none;
  final List<_TierRow> _tiers = [];

  @override
  void dispose() {
    _nameController.dispose();
    _defaultPointsController.dispose();
    _maxSquadController.dispose();
    _customDurationController.dispose();
    for (final tier in _tiers) {
      tier.dispose();
    }
    super.dispose();
  }

  void _addTier() => setState(() => _tiers.add(_TierRow()));

  void _removeTier(int index) => setState(() => _tiers.removeAt(index).dispose());

  int? _resolvedDurationMinutes() {
    if (_durationPreset == _DurationPreset.custom) {
      return int.tryParse(_customDurationController.text.trim());
    }
    return _durationPreset.minutes;
  }

  List<BidIncrementRuleInput>? _resolvedBidIncrementRules() {
    final rules = <BidIncrementRuleInput>[];
    for (final tier in _tiers) {
      final increment = num.tryParse(tier.incrementController.text.trim());
      if (increment == null) continue; // skip incomplete rows silently
      final upToText = tier.upToController.text.trim();
      rules.add(BidIncrementRuleInput(upTo: upToText.isEmpty ? null : num.tryParse(upToText), increment: increment));
    }
    return rules.isEmpty ? null : rules;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      CreateAuctionSessionInput(
        name: _nameController.text.trim(),
        durationMinutes: _resolvedDurationMinutes(),
        defaultTeamPoints: num.tryParse(_defaultPointsController.text.trim()),
        maxSquadSize: int.tryParse(_maxSquadController.text.trim()),
        bidIncrementRules: _resolvedBidIncrementRules(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auction Settings'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Session name',
                hintText: 'e.g. Main Auction — Day 1',
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'TOTAL AUCTION DURATION',
              subtitle: 'Informational only — shown as a countdown, never enforced.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in _DurationPreset.values)
                        ChoiceChip(
                          label: Text(preset.label),
                          selected: _durationPreset == preset,
                          onSelected: (_) => setState(() => _durationPreset = preset),
                        ),
                    ],
                  ),
                  if (_durationPreset == _DurationPreset.custom) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customDurationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Custom duration (minutes)',
                        hintText: 'e.g. 150',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'DEFAULT TEAM POINTS',
              subtitle: "Applied to every registered team's purse when the session starts.",
              child: TextFormField(
                controller: _defaultPointsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Points / purse (₹)', hintText: 'e.g. 15000'),
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'MAX SQUAD SIZE',
              subtitle: 'A team at this roster count can no longer bid ("SQUAD FULL").',
              child: TextFormField(
                controller: _maxSquadController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Players per team', hintText: 'e.g. 15'),
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'BID INCREMENT RULES',
              subtitle: 'Optional tiered schedule. Leave "Up to" blank for the final (no-ceiling) tier. '
                  'Omit entirely to use the default (5% of current bid, rounded).',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _tiers.length; i++) _TierEditor(tier: _tiers[i], onRemove: () => _removeTier(i)),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: _addTier,
                    icon: const Icon(Icons.add),
                    label: const Text('Add tier'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'BID TIMER',
              subtitle: null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.pageBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_clock, size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Text(
                      'Manual (No Auto Timer)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(onPressed: _submit, child: const Text('Create Session')),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _TierEditor extends StatelessWidget {
  const _TierEditor({required this.tier, required this.onRemove});

  final _TierRow tier;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextFormField(
              controller: tier.upToController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Up to (₹)', hintText: 'blank = no ceiling'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: tier.incrementController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Increment (₹)'),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textMuted,
            tooltip: 'Remove tier',
          ),
        ],
      ),
    );
  }
}
