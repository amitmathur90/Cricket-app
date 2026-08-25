import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../tournaments/data/models/points_table_row.dart';
import '../application/public_providers.dart';

/// `GET public/organizations/:organizationId/tournaments/:tournamentId/points-table`
/// — reuses the authenticated `PointsTableRow` model verbatim (see
/// `PublicRepository.getPointsTable`'s doc comment) and the same
/// `DataTable` layout as `PointsTableTab`
/// (features/tournaments/presentation/widgets/points_table_tab.dart), just
/// without any tournament-detail tab chrome around it.
class PublicPointsTableScreen extends ConsumerWidget {
  const PublicPointsTableScreen({
    super.key,
    required this.organizationId,
    required this.tournamentId,
  });

  final String organizationId;
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = (organizationId: organizationId, tournamentId: tournamentId);
    final rowsAsync = ref.watch(publicPointsTableProvider(scope));

    return Scaffold(
      appBar: AppBar(title: const Text('Points Table')),
      body: rowsAsync.when(
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
            onRefresh: () => ref.refresh(publicPointsTableProvider(scope).future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  columns: const [
                    DataColumn(label: Text('Pos')),
                    DataColumn(label: Text('Team')),
                    DataColumn(label: Text('P'), numeric: true),
                    DataColumn(label: Text('W'), numeric: true),
                    DataColumn(label: Text('L'), numeric: true),
                    DataColumn(label: Text('T'), numeric: true),
                    DataColumn(label: Text('NR'), numeric: true),
                    DataColumn(label: Text('Pts'), numeric: true),
                    DataColumn(label: Text('NRR'), numeric: true),
                  ],
                  rows: [for (final row in rows) _rowFor(row)],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text(error is ApiException ? error.message : 'Failed to load points table'),
        ),
      ),
    );
  }

  DataRow _rowFor(PointsTableRow row) {
    return DataRow(
      cells: [
        DataCell(Text('${row.position}')),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(row.teamName, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(Text('${row.played}')),
        DataCell(Text('${row.won}')),
        DataCell(Text('${row.lost}')),
        DataCell(Text('${row.tied}')),
        DataCell(Text('${row.noResult}')),
        DataCell(Text('${row.points}', style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(row.netRunRate.toStringAsFixed(2))),
      ],
    );
  }
}
