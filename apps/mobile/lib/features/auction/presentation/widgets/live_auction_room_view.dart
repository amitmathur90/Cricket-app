import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../players/application/players_providers.dart';
import '../../../players/data/models/player.dart' show PlayerRoleX;
import '../../../tournaments/application/tournaments_providers.dart';
import '../../application/auction_providers.dart';
import '../../application/auction_room_controller.dart';
import '../../application/bid_increment.dart';
import '../../data/models/auction_pool_entry.dart';
import '../../data/models/auction_realtime_models.dart';

/// The live auction room — rendered by AuctionSessionDetailScreen for
/// sessions with status `live` or `paused`. Owns no state itself beyond
/// admin-action busy tracking; all real-time auction state comes from
/// [auctionRoomControllerProvider], a Socket.IO connection to the backend's
/// `/auction` namespace (see auction_room_controller.dart for the
/// event-handling details) — this view is presentation only, styled to
/// match the rest of this app's light theme (`AppColors`), and must not
/// touch that socket/state layer beyond adding the `auction.bidUndone`
/// wiring it already exposes.
///
/// There is no auto-timer driving lot resolution anywhere in this screen —
/// the backend rewrite removed lot auto-resolution entirely (see
/// `AuctionRealtimeService`'s class doc comment). A lot stays open to bids
/// until the admin explicitly marks it SOLD or UNSOLD
/// (`_AdminControlsCard`), and `AuctionCurrentLot.resolved` (not a
/// deadline) is what switches this screen from bidding controls to the
/// SOLD/UNSOLD confirmation + "Next Player" prompt.
///
/// [_AuctionHeader], by contrast, DOES run a real ticking countdown — but
/// it's a completely different concept: a display-only countdown against
/// the session's total configured time budget
/// (`AuctionSession.durationMinutes`, counted down from
/// `AuctionSession.startedAt`), never a per-lot bidding deadline. Nothing
/// server-side enforces it (see that field's doc comment); it's hidden
/// entirely when the session has no `durationMinutes` configured.
///
/// Also watches [auctionPoolListProvider] (a plain REST fetch, not part of
/// the socket state) purely to enrich the current lot's display with two
/// fields the WS payloads don't carry — lot number and player rating (see
/// AuctionLotPlayer's doc comment) — and to compute each team's "players
/// purchased" count plus the header's Sold/Unsold/Remaining tallies.
/// `listPool` returns every pool entry for the session in one call, so a
/// single fetch on first watch covers every lot; it's invalidated only when
/// a lot resolves (sold/unsold), which is the one thing that changes those
/// counts.
///
/// Also watches [auctionSessionDetailProvider] (already used elsewhere in
/// this feature to drive AuctionSessionDetailScreen) purely for
/// `AuctionSession.startedAt` and `bidIncrementRules` — two fields the WS
/// `auction.stateSync` payload doesn't carry
/// (`AuctionRealtimeService.buildStateSyncPayload`'s `session` object is
/// `{id, name, status, tournamentId, durationMinutes, maxSquadSize}` only),
/// but which the plain "get one session" REST endpoint already returns for
/// free (it serializes the full entity, no field projection) — so both are
/// available with no backend change, just an extra `ref.watch` here.
///
/// Note on roles: there is no team-owner-scoped "my team" identity anywhere
/// in this feature (checked auction_providers.dart / auction_room_controller
/// .dart) — this screen is a single admin operator's control panel, bidding
/// on behalf of *any* physical team in the room whenever that team's
/// representative raises a paddle, not a remote team-owner self-service
/// bidding flow. That's why [_TeamsSection] gives every team its own
/// always-visible PLACE BID button (pre-computed amount, immediate submit)
/// rather than a shared team-selector dropdown + one generic button — see
/// that class's doc comment. The admin controls further down are always
/// rendered too and rely on the backend rejecting the call with a 403 for
/// non-admin callers (see _AdminControlsCard's doc comment).
class LiveAuctionRoomView extends ConsumerStatefulWidget {
  const LiveAuctionRoomView({
    super.key,
    required this.organizationId,
    required this.tournamentId,
    required this.sessionId,
  });

  final String organizationId;
  final String tournamentId;
  final String sessionId;

  @override
  ConsumerState<LiveAuctionRoomView> createState() => _LiveAuctionRoomViewState();
}

class _LiveAuctionRoomViewState extends ConsumerState<LiveAuctionRoomView> {
  bool _adminBusy = false;

  AuctionSessionKey get _key => (tournamentId: widget.tournamentId, sessionId: widget.sessionId);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAdminAction(Future<void> Function() action) async {
    setState(() => _adminBusy = true);
    try {
      await action();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _adminBusy = false);
    }
  }

  /// Shows the "Confirm Player Sale?" dialog before actually calling
  /// `markSold` — SOLD must never execute on a single tap (see this file's
  /// task spec). `leadingTeamPurseRemaining` is the leading team's CURRENT
  /// (pre-deduction) purse from live state; "Remaining" here is a
  /// display-only `before - currentBidAmount` estimate — the real
  /// post-deduction value arrives moments later via `auction.playerSold` and
  /// is what the "Player Sold" summary banner shows, not this estimate.
  Future<void> _confirmMarkSold({
    required String playerName,
    required String? leadingTeamName,
    required num currentBidAmount,
    required num? leadingTeamPurseRemaining,
  }) async {
    final before = leadingTeamPurseRemaining;
    final remaining = before != null ? before - currentBidAmount : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Player Sale?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Player: $playerName'),
            const SizedBox(height: 4),
            Text('Team: ${leadingTeamName ?? 'Unknown team'}'),
            const SizedBox(height: 4),
            Text('Final Bid: ₹${_money(currentBidAmount)}'),
            const SizedBox(height: 16),
            const Text('Team Points:', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Before: ${before != null ? '₹${_money(before)}' : '—'}'),
            Text('Spent: ₹${_money(currentBidAmount)}'),
            Text('Remaining: ${remaining != null ? '₹${_money(remaining)}' : '—'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm SOLD'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAdminAction(() =>
        ref.read(auctionRepositoryProvider).markSold(widget.organizationId, widget.tournamentId, widget.sessionId));
  }

  /// Shows the "Mark Player as Unsold?" dialog before calling `markUnsold` —
  /// same never-execute-on-a-single-tap requirement as SOLD, but with no
  /// team/points fields since UNSOLD never touches any team's purse.
  Future<void> _confirmMarkUnsold({required String playerName}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark Player as Unsold?'),
        content: Text(playerName),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm UNSOLD'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runAdminAction(() => ref
        .read(auctionRepositoryProvider)
        .markUnsold(widget.organizationId, widget.tournamentId, widget.sessionId));
  }

  AuctionPlayerPoolEntry? _poolEntryFor(List<AuctionPlayerPoolEntry> pool, String poolEntryId) {
    for (final entry in pool) {
      if (entry.id == poolEntryId) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(auctionRoomControllerProvider(widget.sessionId).notifier);

    ref.listen<AuctionRoomState>(auctionRoomControllerProvider(widget.sessionId), (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        _snack(next.errorMessage!);
        controller.dismissError();
      }
      // The session completes when the admin clicks "Next Player" on the
      // last lot (there is no auto-completion — see this file's class doc
      // comment) — once the room reports `completed`, refresh the outer
      // session snapshot so AuctionSessionDetailScreen switches away from
      // this view.
      if (next.sessionStatus == 'completed' && previous?.sessionStatus != 'completed') {
        ref.invalidate(auctionSessionDetailProvider(_key));
      }
      // A lot just resolved (sold/unsold) — the only thing that changes
      // each team's "players purchased" count and the header's
      // Sold/Unsold/Remaining tallies, so refresh the pool listing those
      // are derived from. (AuctionLotResult has no `==` override, so this
      // compares object identity: true only when a *new* result was set,
      // not on unrelated rebuilds that just carry the previous one
      // forward.)
      if (next.lastResult != null && !identical(next.lastResult, previous?.lastResult)) {
        ref.invalidate(auctionPoolListProvider(_key));
      }
    });

    final roomState = ref.watch(auctionRoomControllerProvider(widget.sessionId));
    final pool = ref.watch(auctionPoolListProvider(_key)).valueOrNull ?? const <AuctionPlayerPoolEntry>[];
    final sessionDetail = ref.watch(auctionSessionDetailProvider(_key)).valueOrNull;
    final tournamentDetail = ref.watch(tournamentDetailProvider(widget.tournamentId)).valueOrNull;
    final lot = roomState.currentLot;
    final isPaused = roomState.sessionStatus == 'paused';
    final hasActiveBid = roomState.bidHistory.any((b) => !b.voided);
    final isResolved = lot?.resolved ?? false;

    AuctionLiveTeam? leadingTeam;
    if (lot != null && lot.currentBidTeamId != null) {
      final matches = roomState.teams.where((t) => t.tournamentTeamId == lot.currentBidTeamId);
      leadingTeam = matches.isEmpty ? null : matches.first;
    }
    final leadingTeamName = leadingTeam?.teamName;
    // The leading team's CURRENT (pre-deduction) purse — used as the "Before"
    // figure in the SOLD confirmation dialog. Null only if the leading team
    // somehow isn't in the live team list or hasn't reported a purse yet.
    final leadingTeamPurseRemaining =
        leadingTeam != null ? num.tryParse(leadingTeam.purseRemaining ?? '') : null;

    final soldCount = pool.where((e) => e.status == AuctionPoolStatus.sold).length;
    final unsoldCount = pool.where((e) => e.status == AuctionPoolStatus.unsold).length;
    // "Remaining" = not yet resolved (pending lots plus whichever one is
    // currently under the hammer) — everything in the pool minus the two
    // resolved buckets above.
    final remainingCount = pool.length - soldCount - unsoldCount;

    final currentBidAmount = num.tryParse(lot?.currentBidAmount ?? lot?.basePrice ?? '') ?? 0;
    final nextBidAmount = computeNextBid(currentBidAmount, sessionDetail?.bidIncrementRules);

    // Squad count for the just-resolved SOLD lot's summary banner — derived
    // from the pool listing the same way _TeamsSection derives each team's
    // live "players purchased" count. `pool` is invalidated right after a
    // lot resolves (see the ref.listen block above), so this picks up the
    // just-sold player once that refetch lands.
    final lastResult = roomState.lastResult;
    int? soldSquadCount;
    if (lastResult != null && lastResult.isSold && lastResult.soldToTeamId != null) {
      soldSquadCount = pool
          .where((e) => e.status == AuctionPoolStatus.sold && e.soldToTeamId == lastResult.soldToTeamId)
          .length;
    }

    return Column(
      children: [
        _AuctionHeader(
          tournamentName: tournamentDetail?.name,
          startedAt: sessionDetail?.startedAt,
          durationMinutes: roomState.durationMinutes,
          soldCount: soldCount,
          unsoldCount: unsoldCount,
          remainingCount: remainingCount,
          connectionStatus: roomState.connectionStatus,
          isPaused: isPaused,
        ),
        if (lastResult != null)
          _ResultBanner(result: lastResult, squadCount: soldSquadCount, maxSquadSize: roomState.maxSquadSize),
        Expanded(
          child: lot == null
              ? const Center(child: Text('Waiting for the next lot...'))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _CurrentLotCard(lot: lot, poolEntry: _poolEntryFor(pool, lot.poolEntryId)),
                    _CurrentBidCard(
                      lot: lot,
                      leadingTeamName: leadingTeamName,
                      nextBidAmount: nextBidAmount,
                    ),
                    _TeamBidTicker(bidHistory: roomState.bidHistory),
                    if (isResolved) const _LotResolvedPrompt(),
                    _TeamsSection(
                      teams: roomState.teams,
                      pool: pool,
                      maxSquadSize: roomState.maxSquadSize,
                      canBid: !isResolved && !isPaused && !_adminBusy,
                      nextBidAmount: nextBidAmount,
                      currentBidTeamId: lot.currentBidTeamId,
                      onPlaceBid: (teamId) => controller.placeBid(teamId: teamId, amount: nextBidAmount),
                    ),
                    _AdminControlsCard(
                      isPaused: isPaused,
                      busy: _adminBusy,
                      hasActiveBid: hasActiveBid,
                      isResolved: isResolved,
                      onPause: () => _runAdminAction(() => ref
                          .read(auctionRepositoryProvider)
                          .pauseSession(widget.organizationId, widget.tournamentId, widget.sessionId)),
                      onResume: () => _runAdminAction(() => ref
                          .read(auctionRepositoryProvider)
                          .resumeSession(widget.organizationId, widget.tournamentId, widget.sessionId)),
                      onMarkSold: () => _confirmMarkSold(
                        playerName: lot.player.fullName,
                        leadingTeamName: leadingTeamName,
                        currentBidAmount: currentBidAmount,
                        leadingTeamPurseRemaining: leadingTeamPurseRemaining,
                      ),
                      onMarkUnsold: () => _confirmMarkUnsold(playerName: lot.player.fullName),
                      onNextLot: () => _runAdminAction(() => ref
                          .read(auctionRepositoryProvider)
                          .nextLot(widget.organizationId, widget.tournamentId, widget.sessionId)),
                      onUndoLastBid: () => _runAdminAction(() => ref
                          .read(auctionRepositoryProvider)
                          .undoLastBid(widget.organizationId, widget.tournamentId, widget.sessionId)),
                    ),
                    _BidHistorySection(bidHistory: roomState.bidHistory),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Formats a possibly-fractional amount for display, dropping a trailing
/// ".0" for whole numbers (`computeNextBid` returns a `num` that's often a
/// plain `double` arithmetic result) rather than showing "₹900.0".
String _money(num value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);

/// Header banner: "LIVE PLAYER AUCTION" branding, the tournament name, an
/// optional live countdown against the session's total time budget, and
/// the pool-wide Sold/Unsold/Remaining counts — plus the existing
/// connection/pause status pill (moved here from the plain "Live Auction"
/// title bar this replaces).
///
/// The countdown is genuinely a live `Timer.periodic`, ticking once a
/// second down to zero — not a static value computed once at build time —
/// but it is completely unrelated to the OLD per-lot auto-resolve timer the
/// backend rewrite removed (see LiveAuctionRoomView's class doc comment):
/// this counts down the WHOLE SESSION's time budget
/// (`startedAt + durationMinutes`), is purely informational (nothing
/// server-side enforces it), and never resolves a lot or advances the
/// auction on reaching zero — it simply stops at 00:00:00. When
/// [durationMinutes] is null (a session created without a time budget) no
/// countdown row is shown at all, rather than fabricating one.
class _AuctionHeader extends StatefulWidget {
  const _AuctionHeader({
    required this.tournamentName,
    required this.startedAt,
    required this.durationMinutes,
    required this.soldCount,
    required this.unsoldCount,
    required this.remainingCount,
    required this.connectionStatus,
    required this.isPaused,
  });

  final String? tournamentName;
  final DateTime? startedAt;
  final int? durationMinutes;
  final int soldCount;
  final int unsoldCount;
  final int remainingCount;
  final AuctionConnectionStatus connectionStatus;
  final bool isPaused;

  @override
  State<_AuctionHeader> createState() => _AuctionHeaderState();
}

class _AuctionHeaderState extends State<_AuctionHeader> {
  Timer? _ticker;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _recompute();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
  }

  @override
  void didUpdateWidget(covariant _AuctionHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt || oldWidget.durationMinutes != widget.durationMinutes) {
      _recompute();
    }
  }

  void _recompute() {
    final startedAt = widget.startedAt;
    final durationMinutes = widget.durationMinutes;
    if (startedAt == null || durationMinutes == null) {
      if (_remaining != null && mounted) setState(() => _remaining = null);
      return;
    }
    final deadline = startedAt.add(Duration(minutes: durationMinutes));
    final remaining = deadline.difference(DateTime.now());
    if (!mounted) return;
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _format(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIVE PLAYER AUCTION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (widget.tournamentName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.tournamentName!,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusIndicator(connectionStatus: widget.connectionStatus, isPaused: widget.isPaused),
            ],
          ),
          if (remaining != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Auction Time Remaining: ${_format(remaining)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _HeaderCountChip(label: 'Players Sold', value: widget.soldCount, color: AppColors.primary),
              const SizedBox(width: 8),
              _HeaderCountChip(label: 'Players Unsold', value: widget.unsoldCount, color: AppColors.negative),
              const SizedBox(width: 8),
              _HeaderCountChip(
                  label: 'Players Remaining', value: widget.remainingCount, color: AppColors.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCountChip extends StatelessWidget {
  const _HeaderCountChip({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corner status indicator: the mockup's `LivePill` when the session is
/// actually live and the socket is connected; a paused pill when the
/// organizer has paused the session (real state, not part of the mockup but
/// existing functionality that must stay visible); and a connection pill
/// only when the socket itself is connecting/disconnected, since that's
/// functionally important (the operator needs to know bids may not be
/// reaching the server) and isn't something the mockup's static LivePill can
/// convey.
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.connectionStatus, required this.isPaused});

  final AuctionConnectionStatus connectionStatus;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    if (connectionStatus != AuctionConnectionStatus.connected) {
      final (label, color) = connectionStatus == AuctionConnectionStatus.connecting
          ? ('CONNECTING', AppColors.amber)
          : ('DISCONNECTED', AppColors.negative);
      return StatusPill(label: label, color: color, icon: Icons.wifi_off);
    }
    if (isPaused) {
      return const StatusPill(label: 'PAUSED', color: AppColors.amber, icon: Icons.pause);
    }
    return const LivePill();
  }
}

/// The "Player Sold"/"Player Unsold" summary panel, shown once
/// [AuctionRoomController] surfaces a [AuctionLotResult] (from
/// `auction.playerSold`/`auction.playerUnsold`) until the next
/// `auction.playerUp` clears it. For a SOLD outcome this shows every field
/// the spec calls for — Player Status, Team, Final Bid, Remaining Points
/// (the server-confirmed `purseRemaining` off the broadcast itself, NOT the
/// pre-computed estimate shown in the confirm dialog before the sale), and
/// Squad count ([squadCount], derived by the caller from the pool listing).
/// A confirmed UNSOLD lot never touches any team's purse, so its summary is
/// deliberately just the status line — no team/points/squad fields apply.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result, this.squadCount, this.maxSquadSize});

  final AuctionLotResult result;

  /// This lot's buying team's players-purchased count, including this sale —
  /// null while unsold, or while the pool refetch triggered by this result
  /// hasn't landed yet.
  final int? squadCount;
  final int? maxSquadSize;

  @override
  Widget build(BuildContext context) {
    final color = result.isSold ? AppColors.primary : AppColors.textSecondary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(result.isSold ? Icons.check_circle : Icons.block, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                'Player Status: ${result.isSold ? 'SOLD' : 'UNSOLD'}',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          if (result.isSold) ...[
            const SizedBox(height: 8),
            _ResultRow('Team', result.soldToTeamName ?? 'Unknown team'),
            _ResultRow('Final Bid', '₹${result.finalPrice}'),
            if (result.purseRemaining != null) _ResultRow('Remaining Points', '₹${result.purseRemaining}'),
            if (squadCount != null)
              _ResultRow('Squad', maxSquadSize != null ? '$squadCount/$maxSquadSize' : '$squadCount'),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Player photo, identity, base-price/rating stat row, and (when available)
/// batting/bowling style — the mockup's "player-up card". The current-bid
/// amount and current leading team live in [_CurrentBidCard] below, matching
/// the mockup's separate tinted "current bid" box.
///
/// `battingStyle`/`bowlingStyle` are real `Player` entity fields (see
/// player.entity.ts) but the WS `auction.playerUp`/`auction.stateSync`
/// payloads' `player` object only ever projects `{id, fullName, role,
/// photoUrl}` (`AuctionRealtimeService.buildStateSyncPayload`/
/// `startSession`/`advanceToNextLot`) — neither style field is in the wire
/// payload for this lot. Rather than leaving them out entirely, this card
/// does a cheap supplementary fetch of the player's full org-level profile
/// (`playerDetailProvider`, `GET .../players/:playerId` — a pre-existing
/// backend endpoint, `PlayersController.findOne`) keyed by the lot's player
/// id, so it refetches automatically whenever the lot changes. While that
/// fetch is in flight (or if both styles are genuinely unset for this
/// player), the styles row is simply omitted — never fabricated.
class _CurrentLotCard extends ConsumerWidget {
  const _CurrentLotCard({required this.lot, required this.poolEntry});

  final AuctionCurrentLot lot;

  /// The pool listing's copy of this lot, if loaded — carries `lotOrder`
  /// and the player's `rating`, neither of which the WS payload includes
  /// (see AuctionLotPlayer's doc comment). Null while the pool fetch is
  /// still in flight; the card degrades gracefully (no lot number, no
  /// rating) rather than blocking on it.
  final AuctionPlayerPoolEntry? poolEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = poolEntry?.player?.rating ?? lot.player.rating;
    final playerDetail = ref.watch(playerDetailProvider(lot.player.id)).valueOrNull;
    final battingStyle = playerDetail?.battingStyle;
    final bowlingStyle = playerDetail?.bowlingStyle;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: lot.player.photoUrl != null
                      ? Image.network(
                          Env.mediaUrl(lot.player.photoUrl!),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const _PlayerPhotoPlaceholder(),
                        )
                      : const _PlayerPhotoPlaceholder(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (poolEntry != null)
                        Text(
                          'Player #${poolEntry!.lotOrder}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        lot.player.fullName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lot.player.role.label,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      if (battingStyle != null || bowlingStyle != null) ...[
                        const SizedBox(height: 6),
                        if (battingStyle != null)
                          Text(
                            'Batting: $battingStyle',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        if (bowlingStyle != null)
                          Text(
                            'Bowling: $bowlingStyle',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _LotStat(label: 'BASE PRICE', value: '₹${lot.basePrice}')),
                Expanded(
                  child: _LotStat(
                    label: 'RATING',
                    value: rating ?? '—',
                    icon: rating != null ? Icons.star : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The tinted "current bid" box: CURRENT BID amount, whether the lot is
/// still open to bids or has been resolved (SOLD/UNSOLD — real data,
/// `AuctionCurrentLot.resolved`, populated from the socket state; there is
/// no timer/deadline anymore, see this file's class doc comment), which
/// team currently holds the lead, and — while the lot is still open — an
/// explicit "Next Bid" preview.
///
/// [nextBidAmount] mirrors the backend's tiered increment computation
/// (`computeMinIncrement` in bid_increment.dart, kept in lockstep with
/// auction-bid-increment.util.ts) rather than a separately-diverging
/// formula, so this preview is accurate for sessions with a custom
/// `bidIncrementRules` schedule, not just the flat 5% default.
class _CurrentBidCard extends StatelessWidget {
  const _CurrentBidCard({required this.lot, required this.leadingTeamName, required this.nextBidAmount});

  final AuctionCurrentLot lot;
  final String? leadingTeamName;
  final num nextBidAmount;

  @override
  Widget build(BuildContext context) {
    final amount = lot.currentBidAmount ?? lot.basePrice;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT BID',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹$amount',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOT STATUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lot.resolved ? 'Resolved' : 'Bidding open',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: lot.resolved ? AppColors.textSecondary : AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HIGHEST BIDDER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      leadingTeamName ?? 'No bids yet',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!lot.resolved) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.trending_up, size: 16, color: AppColors.primaryDark),
                const SizedBox(width: 6),
                Text(
                  'Next Bid  ₹${_money(nextBidAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerPhotoPlaceholder extends StatelessWidget {
  const _PlayerPhotoPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        width: 88,
        height: 88,
        color: AppColors.pageBackground,
        child: const Icon(Icons.person, size: 44, color: AppColors.textMuted),
      );
}

class _LotStat extends StatelessWidget {
  const _LotStat({required this.label, required this.value, this.emphasize = false, this.icon});

  final String label;
  final String value;
  final bool emphasize;

  /// Optional small leading icon shown before the value (e.g. a star for
  /// RATING).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasize
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryDark)
        : Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        if (icon != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.amber),
              const SizedBox(width: 3),
              Text(value, style: valueStyle),
            ],
          )
        else
          Text(value, style: valueStyle),
      ],
    );
  }
}

/// Ranked per-team standing on the CURRENT lot only. There's no dedicated
/// "per-team ticker" structure from the backend (`auction.stateSync`'s
/// `teams[]` carries purse, not per-lot bids) — this derives one from the
/// bid feed [AuctionRoomController] already accumulates from
/// `auction.bidPlaced` events, which is reset to empty on every
/// `auction.playerUp` (see `_onPlayerUp`), so `bidHistory` here is always
/// scoped to the current lot already. Voided (undone) bids are excluded so
/// this reflects each team's real current standing, not stale history.
class _TeamBidTicker extends StatelessWidget {
  const _TeamBidTicker({required this.bidHistory});

  final List<AuctionBidFeedItem> bidHistory;

  @override
  Widget build(BuildContext context) {
    final latestByTeam = <String, AuctionBidFeedItem>{};
    for (final bid in bidHistory) {
      if (bid.voided) continue;
      // bidHistory is newest-first, so the first (non-voided) entry seen
      // per team is that team's latest bid on this lot.
      latestByTeam.putIfAbsent(bid.teamName, () => bid);
    }
    if (latestByTeam.isEmpty) return const SizedBox.shrink();

    final ranked = latestByTeam.values.toList()
      ..sort((a, b) => (num.tryParse(b.amount) ?? 0).compareTo(num.tryParse(a.amount) ?? 0));

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BIDS ON THIS LOT',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            for (final bid in ranked)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(bid.teamName)),
                    Text('₹${bid.amount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Start/Pause/Resume/Sold/Unsold/Next-Player/Undo — already live on this
/// screen (not the session detail screen) prior to this redesign, so no
/// navigation or lifecycle change was needed to consolidate them here; this
/// just groups them under a labelled panel matching this screen's other
/// panels.
///
/// SOLD/UNSOLD/NEXT PLAYER are three separate endpoints now, matching the
/// backend rewrite (`auction.controller.ts` exposes `mark-sold`,
/// `mark-unsold`, and `next-lot` as distinct calls —
/// `AuctionRealtimeService.markSold`/`markUnsold`/`advanceToNextLot`).
/// SOLD/UNSOLD are enabled while the current lot is unresolved (SOLD also
/// requires a current bid, mirroring the backend's own check — "No bids
/// have been placed on this lot — mark it UNSOLD instead"); NEXT PLAYER is
/// enabled only once the lot has been resolved (the backend rejects
/// `next-lot` while a lot is still `IN_PROGRESS`).
///
/// "Extend timer" from an earlier reference mockup is deliberately NOT
/// here: there is no timer anywhere in this spec, manual or automatic, that
/// resolves a lot — see this file's class doc comment. (The header's
/// Auction Time Remaining countdown is a separate, purely informational
/// session-wide budget with no "extend" action of its own.)
///
/// "Start" isn't here either — it only applies to a `scheduled` session,
/// which renders PoolManagementView instead of this view (see
/// AuctionSessionDetailScreen), so it stays there.
///
/// Not per-role hidden — same "let the API reject" RBAC convention as every
/// other admin action in this app; there is no user-role check in this
/// widget tree at all (see the class doc comment on LiveAuctionRoomView), a
/// non-admin caller just gets the 403 surfaced as a snackbar via
/// _runAdminAction/ApiException.
class _AdminControlsCard extends StatelessWidget {
  const _AdminControlsCard({
    required this.isPaused,
    required this.busy,
    required this.hasActiveBid,
    required this.isResolved,
    required this.onPause,
    required this.onResume,
    required this.onMarkSold,
    required this.onMarkUnsold,
    required this.onNextLot,
    required this.onUndoLastBid,
  });

  final bool isPaused;
  final bool busy;
  final bool hasActiveBid;

  /// True once the current lot has been marked SOLD/UNSOLD
  /// (`AuctionCurrentLot.resolved`). This card is only ever rendered by
  /// LiveAuctionRoomView while a current lot exists, so `isResolved` alone
  /// is enough to gate SOLD/UNSOLD vs. NEXT PLAYER.
  final bool isResolved;

  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onMarkSold;
  final Future<void> Function() onMarkUnsold;
  final Future<void> Function() onNextLot;
  final Future<void> Function() onUndoLastBid;

  @override
  Widget build(BuildContext context) {
    final lotOpen = !isResolved;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AUCTION CONTROLS',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPaused)
                  FilledButton.icon(
                    onPressed: busy ? null : onResume,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: busy ? null : onPause,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                FilledButton.icon(
                  onPressed: (busy || !lotOpen || !hasActiveBid) ? null : onMarkSold,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('SOLD'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
                OutlinedButton.icon(
                  onPressed: (busy || !lotOpen) ? null : onMarkUnsold,
                  icon: const Icon(Icons.block),
                  label: const Text('UNSOLD'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary),
                ),
                FilledButton.icon(
                  onPressed: (busy || !isResolved) ? null : onNextLot,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('NEXT PLAYER'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.info),
                ),
                OutlinedButton.icon(
                  onPressed: (busy || !hasActiveBid) ? null : onUndoLastBid,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo last bid'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.negative),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown once the current lot is resolved (`AuctionCurrentLot.resolved`) —
/// the SOLD/UNSOLD outcome itself is already shown by `_ResultBanner`
/// above; this just points the operator at the one valid next action (NEXT
/// PLAYER, in `_AdminControlsCard` below), matching the spec's
/// "confirmation + Next Player prompt instead of bidding controls". The
/// per-team PLACE BID buttons in [_TeamsSection] are also disabled while
/// resolved (see `canBid` there), so this banner and that disabled state
/// agree on there being nothing left to bid on.
class _LotResolvedPrompt extends StatelessWidget {
  const _LotResolvedPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.arrow_downward, size: 18, color: AppColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This lot is resolved. Tap NEXT PLAYER below to continue the auction.',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable bid-history feed for the current lot, newest first. Undone
/// bids stay in the list (struck through, tagged) rather than disappearing
/// — mirrors the backend never hard-deleting a voided bid row (it flips
/// `voided`/`voidedAt` instead; see AuctionBid entity's doc comment). Each
/// row's leading avatar shows the bidding team's initial (there's no team
/// logo in the live payload — `AuctionLiveTeam`/`AuctionBidFeedItem` carry
/// only `teamName`, see auction_realtime_models.dart) instead of the raw
/// bid-sequence number the previous version showed, matching the mockup's
/// "team logo/initial-avatar" row — list order (newest first) already
/// conveys sequence, so nothing is lost by dropping the number.
class _BidHistorySection extends StatelessWidget {
  const _BidHistorySection({required this.bidHistory});

  final List<AuctionBidFeedItem> bidHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bid History', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (bidHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No bids yet for this lot.'),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: bidHistory.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final bid = bidHistory[index];
                  const mutedColor = AppColors.textMuted;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor:
                          bid.voided ? mutedColor.withValues(alpha: 0.3) : _teamAvatarColor(bid.teamName),
                      foregroundColor: Colors.white,
                      child: Text(_teamInitial(bid.teamName)),
                    ),
                    title: Text(
                      bid.teamName,
                      style: bid.voided
                          ? const TextStyle(decoration: TextDecoration.lineThrough, color: mutedColor)
                          : null,
                    ),
                    subtitle: bid.voided
                        ? const Text('Undone by admin', style: TextStyle(color: mutedColor, fontSize: 12))
                        : null,
                    trailing: Text(
                      '₹${bid.amount}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: bid.voided ? TextDecoration.lineThrough : null,
                        color: bid.voided ? mutedColor : AppColors.primaryDark,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Every team's Points/Squad plus a dedicated, always-visible PLACE BID
/// button — this screen models a single admin operator bidding on behalf of
/// physical teams in the room (see LiveAuctionRoomView's class doc comment
/// on there being no team-owner-scoped "my team" identity anywhere in this
/// feature), not remote team-owners self-service bidding for themselves.
///
/// A prior pass modeled bidding as one shared "Place a bid" card: a
/// team-selector dropdown, a free-text amount field, and one generic
/// submit button. That fit a self-service model where the bidder already
/// knows which team they are; it's the wrong shape for an operator running
/// a physical room, who needs to react instantly to whichever team's
/// paddle just went up without first hunting them in a dropdown. So each
/// team gets its own card here with its own button, pre-computed to the
/// exact next valid amount (mirroring the backend's tiered increment via
/// `computeNextBid` — see bid_increment.dart) — tapping it submits that
/// bid immediately, with no manual amount entry and no separate confirm
/// step, matching how a physical auction room actually runs.
///
/// Replaces the previous standalone "Team Purse" section (which only
/// listed Starting/Spent/Remaining points) — this is now the one place
/// showing each team's live status. "Squad" is computed from this
/// session's own sold pool entries per team (`_playersPurchased`), not a
/// true tournament-wide roster count — the live payloads
/// (`AuctionLiveTeam`) only expose a `squadFull` boolean
/// (`AuctionRealtimeService.isSquadFull`, computed from the real
/// `TeamPlayer` roster count server-side), not the underlying count
/// itself, so a team that already had roster entries before this auction
/// started could show `squadFull: true` while this card's fraction still
/// reads under `maxSquadSize`. The PLACE BID button always defers to that
/// authoritative `squadFull` flag (never just the fraction shown) for
/// deciding when to show "SQUAD FULL", so it can't go stale.
class _TeamsSection extends StatelessWidget {
  const _TeamsSection({
    required this.teams,
    required this.pool,
    required this.maxSquadSize,
    required this.canBid,
    required this.nextBidAmount,
    required this.currentBidTeamId,
    required this.onPlaceBid,
  });

  final List<AuctionLiveTeam> teams;
  final List<AuctionPlayerPoolEntry> pool;
  final int? maxSquadSize;

  /// True while the current lot is open to bids (unresolved), the session
  /// isn't paused, and no admin action is already in flight — team-specific
  /// squad-fullness/insufficient-points/leading-bidder checks are layered on
  /// top of this per card, not baked in here.
  final bool canBid;
  final num nextBidAmount;

  /// The current lot's leading bidder, if any (`AuctionCurrentLot.
  /// currentBidTeamId`) — passed down so each card can disable its own
  /// PLACE BID button when IT is already the leading bidder (a team can't
  /// out-bid its own standing bid).
  final String? currentBidTeamId;
  final void Function(String teamId) onPlaceBid;

  int _playersPurchased(AuctionLiveTeam team) => pool
      .where((e) => e.status == AuctionPoolStatus.sold && e.soldToTeamId == team.tournamentTeamId)
      .length;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teams', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final team in teams)
            _TeamActionCard(
              team: team,
              playersPurchased: _playersPurchased(team),
              maxSquadSize: maxSquadSize,
              canBid: canBid,
              nextBidAmount: nextBidAmount,
              isLeadingBidder: currentBidTeamId != null && currentBidTeamId == team.tournamentTeamId,
              onPlaceBid: () => onPlaceBid(team.tournamentTeamId),
            ),
        ],
      ),
    );
  }
}

class _TeamActionCard extends StatelessWidget {
  const _TeamActionCard({
    required this.team,
    required this.playersPurchased,
    required this.maxSquadSize,
    required this.canBid,
    required this.nextBidAmount,
    required this.isLeadingBidder,
    required this.onPlaceBid,
  });

  final AuctionLiveTeam team;
  final int playersPurchased;
  final int? maxSquadSize;
  final bool canBid;
  final num nextBidAmount;

  /// True when this team is already the current lot's leading bidder
  /// (`AuctionCurrentLot.currentBidTeamId == team.tournamentTeamId`) — a
  /// team can't out-bid its own standing bid, so PLACE BID is disabled with
  /// a "Leading Bidder" label in that case. Client-side UX guard only; the
  /// backend doesn't reject same-team re-bids today, but this task's scope
  /// is client-only (see live_auction_room_view.dart's task spec).
  final bool isLeadingBidder;
  final VoidCallback onPlaceBid;

  @override
  Widget build(BuildContext context) {
    // Proactive client-side disables — all purely UX; the server remains the
    // authoritative check regardless (a rejected bid still surfaces via
    // auction.error). Checked in this order because each corresponds to a
    // dedicated button label, and only one can show at a time:
    //   1. squadFull — server-computed, already existed before this pass.
    //   2. isLeadingBidder — this team already holds the standing bid.
    //   3. insufficientPoints — this team's purse can't cover the next bid.
    final purseRemaining = num.tryParse(team.purseRemaining ?? '');
    final insufficientPoints = purseRemaining != null && purseRemaining < nextBidAmount;
    final canActuallyBid = canBid && !team.squadFull && !isLeadingBidder && !insufficientPoints;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // The colored dot/badge is this team's rotating avatar
                // color, keyed by a stable hash of its name — see
                // _teamAvatarColor's doc comment.
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _teamAvatarColor(team.teamName),
                  foregroundColor: Colors.white,
                  child: Text(_teamInitial(team.teamName), style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    team.teamName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LotStat(
                    label: 'POINTS',
                    value: team.purseRemaining != null ? '₹${team.purseRemaining}' : '—',
                    emphasize: true,
                  ),
                ),
                Expanded(
                  child: _LotStat(
                    label: 'SQUAD',
                    value: maxSquadSize != null ? '$playersPurchased/$maxSquadSize' : '$playersPurchased',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: team.squadFull
                  ? _DisabledTeamButton(label: 'SQUAD FULL')
                  : isLeadingBidder
                      ? _DisabledTeamButton(label: 'Leading Bidder')
                      : insufficientPoints
                          ? _DisabledTeamButton(label: 'Insufficient Points')
                          : FilledButton(
                              onPressed: canActuallyBid ? onPlaceBid : null,
                              child: Text(
                                'PLACE BID  ₹${_money(nextBidAmount)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared visual for every proactive-disable state on a team's PLACE BID
/// button (SQUAD FULL / Leading Bidder / Insufficient Points) — same
/// negative-toned outlined look the SQUAD FULL case already used before this
/// pass, just factored out so all three disable reasons render identically.
class _DisabledTeamButton extends StatelessWidget {
  const _DisabledTeamButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.negative,
        disabledForegroundColor: AppColors.negative,
        side: const BorderSide(color: AppColors.negative),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

/// Rotating accent palette for team initial-avatars — same set used for
/// stat-card badges/chart legends elsewhere (AppColors.accents), keyed by a
/// stable hash of the team name so a given team always gets the same color
/// across the bid-history feed and the Teams section.
Color _teamAvatarColor(String teamName) =>
    AppColors.accents[teamName.hashCode.abs() % AppColors.accents.length];

String _teamInitial(String teamName) => teamName.isEmpty ? '?' : teamName[0].toUpperCase();
