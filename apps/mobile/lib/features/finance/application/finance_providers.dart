import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/finance_repository.dart';
import '../data/models/finance_dashboard.dart';
import '../data/models/finance_transaction.dart';
import '../data/models/player_fee.dart';
import '../data/models/team_fee.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(apiClientProvider));
});

/// The Finance tab is always reached from within one tournament's detail
/// screen (see TournamentDetailScreen), same "tournament-scoped, not
/// org-wide" logic as Points Table/Matches — so every provider below takes
/// a `tournamentId` rather than exposing an org-wide aggregate view.
final financeDashboardProvider =
    FutureProvider.autoDispose.family<FinanceDashboard, String>((ref, tournamentId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(financeRepositoryProvider).getDashboard(organizationId, tournamentId: tournamentId);
});

/// Filter selection for [financeTransactionsListProvider] — `category`/`type`
/// null means "no filter" (all transactions for the tournament).
typedef FinanceTransactionsQuery = ({
  String tournamentId,
  FinanceTransactionCategory? category,
  FinanceTransactionType? type,
});

final financeTransactionsListProvider = FutureProvider.autoDispose
    .family<List<FinanceTransaction>, FinanceTransactionsQuery>((ref, query) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(financeRepositoryProvider).listTransactions(
        organizationId,
        tournamentId: query.tournamentId,
        category: query.category,
        type: query.type,
      );
});

final financeTransactionDetailProvider =
    FutureProvider.autoDispose.family<FinanceTransaction, String>((ref, transactionId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) {
    throw StateError('No active organization');
  }
  return ref.watch(financeRepositoryProvider).getTransaction(organizationId, transactionId);
});

final financeTeamFeesProvider =
    FutureProvider.autoDispose.family<List<TeamFeeRow>, String>((ref, tournamentId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(financeRepositoryProvider).getTeamFees(organizationId, tournamentId);
});

final financePlayerFeesProvider =
    FutureProvider.autoDispose.family<List<PlayerFeeRow>, String>((ref, tournamentId) async {
  final organizationId = ref.watch(sessionControllerProvider.select((s) => s.activeOrgId));
  if (organizationId == null) return const [];
  return ref.watch(financeRepositoryProvider).getPlayerFees(organizationId, tournamentId);
});
