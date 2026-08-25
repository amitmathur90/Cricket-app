import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../../players/data/models/player.dart' show PlayerRoleX;
import '../../application/auction_providers.dart';
import '../../application/auction_room_controller.dart';
import '../../data/models/auction_pool_entry.dart';
import '../../data/models/auction_realtime_models.dart';

/// The live auction room — rendered by AuctionSessionDetailScreen for
/// sessions with status `live` or `paused`. Owns no state itself beyond the
/// bid-entry form; all real-time auction state comes from
/// [auctionRoomControllerProvider], a Socket.IO connection to the backend's
/// `/auction` namespace (see auction_room_controller.dart for the
/// event-handling details) — this view is presentation only, restyled to
/// match the live-auction-room mockup, and must not touch that socket/state
/// layer beyond adding the `auction.bidUndone` wiring it already exposes.
///
/// Also watches [auctionPoolListProvider] (a plain REST fetch, not part of
/// the socket state) purely to enrich the current lot's display with two
/// fields the WS payloads don't carry — lot number and player rating (see
/// AuctionLotPlayer's doc comment) — and to compute each team's "players
/// purchased" count for the Team Purse section. `listPool` returns every
/// pool entry for the session in one call, so a single fetch on first watch
/// covers every lot; it's invalidated only when a lot resolves (sold/
/// unsold), which is the one thing that changes the purchased-count.
///
/// Note on roles: there is no team-owner-scoped "my team" identity anywhere
/// in this feature (checked auction_providers.dart / auction_room_controller
/// .dart) — the "Bidding as team" dropdown below lets the operator place a
/// bid on behalf of *any* tournament team, and the admin controls further
/// down are always rendered and rely on the backend rejecting the call with
/// a 403 for non-admin callers (see _AdminControlsCard's doc comment). So
/// this screen is a single organizer/bidding console, not a per-role split
/// view — the mockup's "Your Team Purse" (implying one team's own panel) is
/// adapted below as "Team Purse" listing every team, unchanged from before
/// this restyle.
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
  final _bidAmountController = TextEditingController();
  String? _selectedTeamId;
  bool _adminBusy = false;

  @override
  void initState() {
    super.initState();
    // Only used to re-derive the "PLACE BID ₹X" button label live as the
    // user types — see the AnimatedBuilder around the bid button below.
    _bidAmountController.addListener(_onBidAmountChanged);
  }

  void _onBidAmountChanged() => setState(() {});

  @override
  void dispose() {
    _bidAmountController.removeListener(_onBidAmountChanged);
    _bidAmountController.dispose();
    super.dispose();
  }

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

  void _placeBid(AuctionRoomController controller) {
    final teamId = _selectedTeamId;
    if (teamId == null) {
      _snack('Select a team first');
      return;
    }
    final amount = num.tryParse(_bidAmountController.text.trim());
    if (amount == null || amount <= 0) {
      _snack('Enter a valid bid amount');
      return;
    }
    controller.placeBid(teamId: teamId, amount: amount);
  }

  /// Client-side suggestion only (shown as a hint/preview) — mirrors the
  /// backend's default increment formula (computeMinIncrement in
  /// auction-bid-increment.util.ts) for sessions with no custom
  /// bidIncrementRules, which is all sessions created by this M1 UI. The
  /// backend is the sole source of truth for what it actually accepts.
  num _suggestedNextBid(String currentBidAmount) {
    final currentBid = num.tryParse(currentBidAmount) ?? 0;
    final unit = currentBid >= 100000 ? 5000 : (currentBid >= 10000 ? 1000 : 100);
    final raw = currentBid * 0.05;
    final increment = raw > unit ? (raw / unit).ceil() * unit : unit;
    return currentBid + increment;
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
      // The session can complete either via a manual "next lot" or the lot
      // timer naturally expiring on the last lot — either way, once the
      // room reports `completed`, refresh the outer session snapshot so
      // AuctionSessionDetailScreen switches away from this view.
      if (next.sessionStatus == 'completed' && previous?.sessionStatus != 'completed') {
        ref.invalidate(auctionSessionDetailProvider(_key));
      }
      // A lot just resolved (sold/unsold) — the only thing that changes
      // each team's "players purchased" count in the Team Purse section
      // below, so refresh the pool listing that count is derived from.
      // (AuctionLotResult has no `==` override, so this compares object
      // identity: true only when a *new* result was set, not on unrelated
      // rebuilds that just carry the previous one forward.)
      if (next.lastResult != null && !identical(next.lastResult, previous?.lastResult)) {
        ref.invalidate(auctionPoolListProvider(_key));
      }
    });

    final roomState = ref.watch(auctionRoomControllerProvider(widget.sessionId));
    final pool = ref.watch(auctionPoolListProvider(_key)).valueOrNull ?? const <AuctionPlayerPoolEntry>[];
    final lot = roomState.currentLot;
    final isPaused = roomState.sessionStatus == 'paused';
    final hasActiveBid = roomState.bidHistory.any((b) => !b.voided);

    String? leadingTeamName;
    if (lot != null && lot.currentBidTeamId != null) {
      final matches = roomState.teams.where((t) => t.tournamentTeamId == lot.currentBidTeamId);
      leadingTeamName = matches.isEmpty ? null : matches.first.teamName;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                'Live Auction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              _StatusIndicator(connectionStatus: roomState.connectionStatus, isPaused: isPaused),
            ],
          ),
        ),
        if (roomState.lastResult != null) _ResultBanner(result: roomState.lastResult!),
        Expanded(
          child: lot == null
              ? const Center(child: Text('Waiting for the next lot...'))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    _CurrentLotCard(lot: lot, poolEntry: _poolEntryFor(pool, lot.poolEntryId)),
                    _CurrentBidCard(lot: lot, leadingTeamName: leadingTeamName),
                    _TeamBidTicker(bidHistory: roomState.bidHistory),
                    Card(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Place a bid', style: Theme.of(context).textTheme.labelLarge),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedTeamId,
                                    decoration: const InputDecoration(labelText: 'Bidding as team'),
                                    items: roomState.teams
                                        .map((t) => DropdownMenuItem(
                                              value: t.tournamentTeamId,
                                              child: Text(t.teamName),
                                            ))
                                        .toList(),
                                    onChanged: (value) => setState(() => _selectedTeamId = value),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _bidAmountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Bid amount (₹)',
                                      hintText:
                                          '₹${_suggestedNextBid(lot.currentBidAmount ?? lot.basePrice)}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: () => _placeBid(controller),
                                child: Text(
                                  'PLACE BID  ₹${(num.tryParse(_bidAmountController.text.trim()) ?? _suggestedNextBid(lot.currentBidAmount ?? lot.basePrice)).toString()}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _AdminControlsCard(
                      isPaused: isPaused,
                      busy: _adminBusy,
                      hasActiveBid: hasActiveBid,
                      onPause: () => _runAdminAction(() => ref
                          .read(auctionRepositoryProvider)
                          .pauseSession(widget.organizationId, widget.tournamentId, widget.sessionId)),
                      onResume: () => _runAdminAction(() => ref
                          .read(auctionRepositoryProvider)
                          .resumeSession(widget.organizationId, widget.tournamentId, widget.sessionId)),
                      onNextLot: () => _runAdminAction(() => ref
                          .read(auctionRepositoryProvider)
                          .nextLot(widget.organizationId, widget.tournamentId, widget.sessionId)),
                      onUndoLastBid: () => _runAdminAction(() => ref
                          .read(auctionRepositoryProvider)
                          .undoLastBid(widget.organizationId, widget.tournamentId, widget.sessionId)),
                    ),
                    _BidHistorySection(bidHistory: roomState.bidHistory),
                    _TeamPurseSection(teams: roomState.teams, pool: pool),
                  ],
                ),
        ),
      ],
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
          : ('DISCONNECTED', AppColors.live);
      return StatusPill(label: label, color: color, icon: Icons.wifi_off);
    }
    if (isPaused) {
      return const StatusPill(label: 'PAUSED', color: AppColors.amber, icon: Icons.pause);
    }
    return const LivePill();
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final AuctionLotResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.isSold ? AppColors.primary : AppColors.textSecondary;
    final text = result.isSold
        ? 'SOLD for ₹${result.finalPrice} to ${result.soldToTeamName ?? 'unknown team'}'
        : 'UNSOLD';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(result.isSold ? Icons.check_circle : Icons.block, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Player photo, identity, and the base-price/rating stat row — the
/// mockup's "player-up card". The current-bid amount and current leading
/// team moved out of this card and into [_CurrentBidCard] below, matching
/// the mockup's separate tinted "current bid" box.
class _CurrentLotCard extends StatelessWidget {
  const _CurrentLotCard({required this.lot, required this.poolEntry});

  final AuctionCurrentLot lot;

  /// The pool listing's copy of this lot, if loaded — carries `lotOrder`
  /// and the player's `rating`, neither of which the WS payload includes
  /// (see AuctionLotPlayer's doc comment). Null while the pool fetch is
  /// still in flight; the card degrades gracefully (no lot number, no
  /// rating) rather than blocking on it.
  final AuctionPlayerPoolEntry? poolEntry;

  @override
  Widget build(BuildContext context) {
    final rating = poolEntry?.player?.rating ?? lot.player.rating;

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

/// The mockup's tinted "current bid" box: CURRENT BID amount, a live
/// countdown to when this lot auto-resolves (real data — `currentLotEndsAt`
/// comes straight off `AuctionCurrentLot`, populated from the socket state
/// and reset on every accepted bid; see auction_room_controller.dart), and
/// which team currently holds the lead.
class _CurrentBidCard extends StatelessWidget {
  const _CurrentBidCard({required this.lot, required this.leadingTeamName});

  final AuctionCurrentLot lot;
  final String? leadingTeamName;

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
                      'NEXT PLAYER IN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (lot.currentLotEndsAt != null)
                      _NextPlayerCountdown(endsAt: lot.currentLotEndsAt!)
                    else
                      const Text('—', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BY',
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

/// Start/Pause/Resume/Resolve-lot/Undo — already live on this screen (not
/// the session detail screen) prior to this redesign, so no navigation or
/// lifecycle change was needed to consolidate them here; this just groups
/// them under a labelled panel matching the mockup's "Auction Controls"
/// block and adds the new Undo-last-bid action.
///
/// Two mockup controls are deliberately NOT here:
///  - "Extend timer": the backend has no manual-extend endpoint
///    (auction.controller.ts exposes only start/pause/resume/next-lot/
///    undo-last-bid) — it auto-extends the lot countdown by
///    REBID_EXTENSION_MS on every accepted bid instead
///    (auction-realtime.service.ts). Wiring a button to nothing would be
///    faking a capability that isn't there.
///  - Separate "Mark sold" / "Mark unsold": there's no such pair of
///    endpoints either. `next-lot` (labelled "Resolve lot & next" here)
///    IS that action, merged: `manualNextLot` force-resolves the current
///    lot — sold to the leading bid if there is one, unsold otherwise —
///    and advances, in one call (auction-realtime.service.ts,
///    `manualNextLot` -> `resolveLot({ force: true })`).
///
/// "Start" isn't here either — it only applies to a `scheduled` session,
/// which renders PoolManagementView instead of this view (see
/// AuctionSessionDetailScreen), so it stays there.
///
/// Not per-role hidden — same "let the API reject" RBAC convention as every
/// other admin action in this app; there is no user-role check in this
/// widget tree at all (see the class doc comment on LiveAuctionRoomView), a
/// non-admin caller just gets the 403 surfaced as a snackbar via
/// _runAdminAction/ApiException. This redesign does not change that.
class _AdminControlsCard extends StatelessWidget {
  const _AdminControlsCard({
    required this.isPaused,
    required this.busy,
    required this.hasActiveBid,
    required this.onPause,
    required this.onResume,
    required this.onNextLot,
    required this.onUndoLastBid,
  });

  final bool isPaused;
  final bool busy;
  final bool hasActiveBid;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onNextLot;
  final Future<void> Function() onUndoLastBid;

  @override
  Widget build(BuildContext context) {
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
                OutlinedButton.icon(
                  onPressed: busy ? null : onNextLot,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Resolve lot & next'),
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

/// Every team's Starting/Spent/Remaining Points and players purchased.
/// "Points" is a deliberate, screen-scoped relabelling of what the data
/// layer still calls "purse" everywhere else (`AuctionLiveTeam.purseTotal`/
/// `purseRemaining`, the REST/WS field names) — display-only, per explicit
/// product direction for this screen; no backend field or other screen's
/// copy changes.
///
/// `purseTotal`/`purseRemaining` come straight from `auction.stateSync`'s
/// `teams[]` (live-updating). "Spent" isn't sent separately — it's derived
/// here as `purseTotal - purseRemaining`. "Players Purchased" isn't in the
/// live team payload either, so it's derived by counting this team's sold
/// pool entries out of the full pool listing (`auctionPoolListProvider`),
/// refreshed whenever a lot resolves (see the `ref.listen` block above).
///
/// Lists every team, not just "your" team — see LiveAuctionRoomView's class
/// doc comment for why (no team-owner identity exists in this feature).
class _TeamPurseSection extends StatelessWidget {
  const _TeamPurseSection({required this.teams, required this.pool});

  final List<AuctionLiveTeam> teams;
  final List<AuctionPlayerPoolEntry> pool;

  int _playersPurchased(AuctionLiveTeam team) => pool
      .where((e) => e.status == AuctionPoolStatus.sold && e.soldToTeamId == team.tournamentTeamId)
      .length;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team Purse', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final team in teams)
            _TeamPurseCard(team: team, playersPurchased: _playersPurchased(team)),
        ],
      ),
    );
  }
}

class _TeamPurseCard extends StatelessWidget {
  const _TeamPurseCard({required this.team, required this.playersPurchased});

  final AuctionLiveTeam team;
  final int playersPurchased;

  @override
  Widget build(BuildContext context) {
    final total = num.tryParse(team.purseTotal ?? '');
    final remaining = num.tryParse(team.purseRemaining ?? '');
    final spent = (total != null && remaining != null) ? (total - remaining) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _teamAvatarColor(team.teamName),
                  foregroundColor: Colors.white,
                  child: Text(_teamInitial(team.teamName), style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(team.teamName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(
                  '$playersPurchased players',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LotStat(
                    label: 'STARTING POINTS',
                    value: team.purseTotal != null ? '₹${team.purseTotal}' : '—',
                  ),
                ),
                Expanded(
                  child: _LotStat(label: 'SPENT', value: spent != null ? '₹${spent.toStringAsFixed(2)}' : '—'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _LotStat(
                    label: 'REMAINING',
                    value: team.purseRemaining != null ? '₹${team.purseRemaining}' : '—',
                    emphasize: true,
                  ),
                ),
                Expanded(
                  child: _LotStat(label: 'PLAYERS PURCHASED', value: '$playersPurchased'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A live "M:SS" countdown to [endsAt] — used inside [_CurrentBidCard] as
/// the mockup's "Next Player" timer value. Ticks every second purely to
/// re-render; the actual deadline is server-driven (`currentLotEndsAt` on
/// the socket state) and gets reset by the controller on every accepted bid
/// or admin action, so this widget never owns or extends the deadline
/// itself — it only ever displays time remaining until it.
class _NextPlayerCountdown extends StatefulWidget {
  const _NextPlayerCountdown({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_NextPlayerCountdown> createState() => _NextPlayerCountdownState();
}

class _NextPlayerCountdownState extends State<_NextPlayerCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.endsAt.difference(DateTime.now());
    final totalSeconds = remaining.isNegative ? 0 : remaining.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final label = '$minutes:${seconds.toString().padLeft(2, '0')}';
    return Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: totalSeconds <= 5 ? AppColors.live : AppColors.textPrimary,
      ),
    );
  }
}

/// Rotating accent palette for team initial-avatars — same set used for
/// stat-card badges/chart legends elsewhere (AppColors.accents), keyed by a
/// stable hash of the team name so a given team always gets the same color
/// across the bid-history feed and the Team Purse section.
Color _teamAvatarColor(String teamName) =>
    AppColors.accents[teamName.hashCode.abs() % AppColors.accents.length];

String _teamInitial(String teamName) => teamName.isEmpty ? '?' : teamName[0].toUpperCase();
