import '../../../core/network/api_client.dart';
import 'models/finance_dashboard.dart';
import 'models/finance_transaction.dart';
import 'models/player_fee.dart';
import 'models/team_fee.dart';

/// Talks to `FinanceController`
/// (apps/backend/src/modules/finance/finance.controller.ts). All routes are
/// nested under the organization only (`organizations/:organizationId/finance`
/// — unlike auction, which nests under a tournament too), so
/// tournament-scoping is expressed as a query parameter (`tournamentId`)
/// rather than a path segment, matching `DashboardQueryDto`/
/// `QueryFinanceTransactionsDto`/`TournamentScopeQueryDto`.
class FinanceRepository {
  FinanceRepository(this._apiClient);

  final ApiClient _apiClient;

  String _base(String organizationId) => '/organizations/$organizationId/finance';

  Future<FinanceTransaction> create(
    String organizationId, {
    String? tournamentId,
    required FinanceTransactionCategory category,
    required FinanceTransactionType type,
    required num amount,
    String? description,
    required String referenceDate,
  }) async {
    final response = await _apiClient.post(
      '${_base(organizationId)}/transactions',
      data: {
        if (tournamentId != null) 'tournamentId': tournamentId,
        'category': category.apiValue,
        'type': type.apiValue,
        'amount': amount,
        if (description != null) 'description': description,
        'referenceDate': referenceDate,
      },
    );
    return FinanceTransaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<FinanceTransaction>> listTransactions(
    String organizationId, {
    String? tournamentId,
    FinanceTransactionCategory? category,
    FinanceTransactionType? type,
    String? from,
    String? to,
  }) async {
    final response = await _apiClient.get(
      '${_base(organizationId)}/transactions',
      queryParameters: {
        if (tournamentId != null) 'tournamentId': tournamentId,
        if (category != null) 'category': category.apiValue,
        if (type != null) 'type': type.apiValue,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => FinanceTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FinanceTransaction> getTransaction(String organizationId, String transactionId) async {
    final response = await _apiClient.get('${_base(organizationId)}/transactions/$transactionId');
    return FinanceTransaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FinanceTransaction> update(
    String organizationId,
    String transactionId, {
    String? tournamentId,
    required FinanceTransactionCategory category,
    required FinanceTransactionType type,
    required num amount,
    String? description,
    required String referenceDate,
  }) async {
    final response = await _apiClient.patch(
      '${_base(organizationId)}/transactions/$transactionId',
      data: {
        'tournamentId': tournamentId,
        'category': category.apiValue,
        'type': type.apiValue,
        'amount': amount,
        'description': description,
        'referenceDate': referenceDate,
      },
    );
    return FinanceTransaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> remove(String organizationId, String transactionId) async {
    await _apiClient.delete('${_base(organizationId)}/transactions/$transactionId');
  }

  Future<FinanceDashboard> getDashboard(String organizationId, {String? tournamentId}) async {
    final response = await _apiClient.get(
      '${_base(organizationId)}/dashboard',
      queryParameters: tournamentId != null ? {'tournamentId': tournamentId} : null,
    );
    return FinanceDashboard.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<TeamFeeRow>> getTeamFees(String organizationId, String tournamentId) async {
    final response = await _apiClient.get(
      '${_base(organizationId)}/team-fees',
      queryParameters: {'tournamentId': tournamentId},
    );
    return (response.data as List<dynamic>)
        .map((e) => TeamFeeRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PlayerFeeRow>> getPlayerFees(String organizationId, String tournamentId) async {
    final response = await _apiClient.get(
      '${_base(organizationId)}/player-fees',
      queryParameters: {'tournamentId': tournamentId},
    );
    return (response.data as List<dynamic>)
        .map((e) => PlayerFeeRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
