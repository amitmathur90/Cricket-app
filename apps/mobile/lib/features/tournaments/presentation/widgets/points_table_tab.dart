import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/tournaments_providers.dart';
import '../../data/models/points_table_row.dart';

/// Points Table tab within TournamentDetailScreen — `GET
/// .../tournaments/:tournamentId/points-table` rendered as a standings
/// table (#, Team, Played, Won, Lost, No Result, Points, NRR). Sort order is
/// exactly what the backend returns (position ascending) — this widget does
/// no client-side re-sorting.
///
/// Restyled to match the same "panel" language as `DashboardOverview`'s
/// Points Table preview (`_PointsTablePreview`) — same NRR green/red
/// coloring ([AppColors.positive]/[AppColors.negative]), bold Pts column,
/// card-wrapped rows — so the full table and the dashboard's top-5 preview
/// read as one consistent component rather than two different designs.
///
/// Two things the reference mockup called for that are deliberately *not*
/// here, to avoid faking functionality the backend doesn't support yet:
///  - An "..." overflow menu next to the title: no export/share action
///    exists anywhere on this tab today, so there'd be nothing to put in it.
///  - "Group A" / "Group B" filter chips: `TournamentGroup` /
///    `tournament_teams.groupId` exist as backend entities, but
///    `TournamentsService.getPointsTable`'s doc comment states groups are
///    "populated but not read anywhere else in the codebase — no group-scoped
///    standings/fixture endpoint exists yet." `PointsTableRow` (this file's
///    data model) carries no group field at all, so there is nothing to
///    filter by on the client either. Only the single, real "All Teams"
///    state is shown below.
class PointsTableTab extends ConsumerWidget {
  const PointsTableTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(pointsTableProvider(tournamentId));

    return rowsAsync.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No standings yet — the points table fills in once teams are registered and '
                'matches are completed.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(pointsTableProvider(tournamentId).future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Points Table', style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Only the real filter state — see the class doc comment for
                // why "Group A" / "Group B" chips are omitted.
                ChoiceChip(
                  label: const Text('All Teams'),
                  selected: true,
                  onSelected: (_) {},
                  selectedColor: AppColors.primary.withValues(alpha: 0.12),
                  labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  side: const BorderSide(color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _PointsTable(rows: rows),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(error is ApiException ? error.message : 'Failed to load points table'),
      ),
    );
  }
}

/// The restyled standings table — still a `DataTable` (the mockup shows a
/// table, not cards) inside its own horizontal scroll view so it stays
/// usable on a narrow phone, but with clear column headers, consistent row
/// padding, subtle zebra striping ([AppColors.pageBackground] on alternate
/// rows), and NRR colored the same way as the dashboard preview.
class _PointsTable extends StatelessWidget {
  const _PointsTable({required this.rows});

  final List<PointsTableRow> rows;

  @override
  Widget build(BuildContext context) {
    final headingStyle = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary);

    return DataTable(
      headingRowColor: WidgetStateProperty.all(AppColors.pageBackground),
      headingTextStyle: headingStyle,
      dataRowMinHeight: 52,
      dataRowMaxHeight: 52,
      columnSpacing: 20,
      horizontalMargin: 16,
      dividerThickness: 0,
      columns: const [
        DataColumn(label: Text('#')),
        DataColumn(label: Text('Team')),
        DataColumn(label: Text('P'), numeric: true),
        DataColumn(label: Text('W'), numeric: true),
        DataColumn(label: Text('L'), numeric: true),
        DataColumn(label: Text('NR'), numeric: true),
        DataColumn(label: Text('Pts'), numeric: true),
        DataColumn(label: Text('NRR'), numeric: true),
      ],
      rows: [
        for (var i = 0; i < rows.length; i++) _rowFor(rows[i], zebra: i.isOdd),
      ],
    );
  }

  DataRow _rowFor(PointsTableRow row, {required bool zebra}) {
    final nrrColor = row.netRunRate > 0
        ? AppColors.positive
        : row.netRunRate < 0
            ? AppColors.negative
            : AppColors.textSecondary;
    return DataRow(
      color: WidgetStateProperty.all(zebra ? AppColors.pageBackground : AppColors.cardBackground),
      cells: [
        DataCell(
          Text('${row.position}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              row.teamName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        DataCell(Text('${row.played}')),
        DataCell(Text('${row.won}')),
        DataCell(Text('${row.lost}')),
        DataCell(Text('${row.noResult}')),
        DataCell(
          Text(
            '${row.points}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
        DataCell(
          Text(
            row.netRunRate.toStringAsFixed(2),
            style: TextStyle(color: nrrColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
