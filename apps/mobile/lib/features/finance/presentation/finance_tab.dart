import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../application/finance_providers.dart';
import 'widgets/finance_summary_section.dart';

/// Tournament detail's "Finance" tab — the mobile translation of the
/// reference mockup's Finance dashboard. Shows the revenue/expense summary
/// directly (own `GET .../finance/dashboard?tournamentId=...` call, same
/// "embed the report, don't just link to it" choice as PointsTableTab)
/// plus three navigation cards into the fuller flows that don't fit in a
/// tab: the unified transaction list/add/edit (covering the spec's
/// Auction transactions/Sponsorship/Ground expenses/Officials
/// payment/Other expenses modules — the backend models these as one
/// filterable list, not five screens, so this app follows that shape), and
/// the read-only Team fees / Player fees views (the spec's "Team fees" /
/// "Player fees" modules).
class FinanceTab extends ConsumerWidget {
  const FinanceTab({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(financeDashboardProvider(tournamentId));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(financeDashboardProvider(tournamentId).future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text('Finance Overview', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          dashboardAsync.when(
            data: (dashboard) => FinanceSummarySection(dashboard: dashboard),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                error is ApiException ? error.message : 'Failed to load finance dashboard',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _NavCard(
            icon: Icons.receipt_long_outlined,
            iconColor: AppColors.info,
            title: 'Transactions',
            subtitle: 'Sponsorship, ground, officials, other income/expenses — filter and add records',
            onTap: () => context.push(financeTransactionsPath(tournamentId)),
          ),
          const SizedBox(height: 10),
          _NavCard(
            icon: Icons.groups_2_outlined,
            iconColor: AppColors.purple,
            title: 'Team fees',
            subtitle: 'Registration fee owed per registered team',
            onTap: () => context.push(financeTeamFeesPath(tournamentId)),
          ),
          const SizedBox(height: 10),
          _NavCard(
            icon: Icons.person_outline,
            iconColor: AppColors.teal,
            title: 'Player fees',
            subtitle: 'Registration fee owed per registered player',
            onTap: () => context.push(financePlayerFeesPath(tournamentId)),
          ),
        ],
      ),
    );
  }
}

/// A restyled nav link card — white card, bordered/rounded via the app's
/// shared `CardTheme`, with a colored icon badge (same 40x40 rounded-square
/// language as [DashboardStatCard]'s icon badge) in place of the previous
/// plain `ListTile` leading icon.
class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
