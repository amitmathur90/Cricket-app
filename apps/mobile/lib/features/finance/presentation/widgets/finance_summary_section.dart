import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/finance_dashboard.dart';
import 'finance_format.dart';

/// The Finance tab's summary section — mobile translation of the reference
/// mockup's Finance Overview panel: three left-accent-bar stat cards (Total
/// Revenue / Total Expenses / Net Profit) followed by a Revenue Breakdown
/// donut chart with a color legend.
///
/// The mockup's stat cards each carry a "+X% from last month" delta line,
/// but `FinanceDashboard` (mirrors the backend's `DashboardResponse`) is
/// entirely point-in-time — `totalRevenue`/`totalExpenses`/`netBalance` have
/// no prior-period figure anywhere to diff against. Per this app's existing
/// "don't fabricate data" precedent (see `dashboard_overview.dart`'s doc
/// comment on why its Revenue card omits the same delta), the delta line is
/// dropped rather than invented — the real totals are still shown.
///
/// The donut chart is hand-drawn with a `CustomPainter` (see
/// [_DonutChartPainter]) rather than a chart package, since none is
/// installed and this redesign is scoped to avoid adding one.
class FinanceSummarySection extends StatelessWidget {
  const FinanceSummarySection({super.key, required this.dashboard});

  final FinanceDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final netBalance = double.tryParse(dashboard.netBalance) ?? 0;
    final netColor = netBalance < 0 ? AppColors.negative : AppColors.positive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FinanceStatCard(
          icon: Icons.trending_up_rounded,
          label: 'Total Revenue',
          value: formatInr(dashboard.totalRevenue),
          accentColor: AppColors.info,
        ),
        const SizedBox(height: 12),
        _FinanceStatCard(
          icon: Icons.trending_down_rounded,
          label: 'Total Expenses',
          value: formatInr(dashboard.totalExpenses),
          accentColor: AppColors.orange,
        ),
        const SizedBox(height: 12),
        _FinanceStatCard(
          icon: Icons.savings_rounded,
          label: 'Net Profit',
          value: formatInr(dashboard.netBalance),
          accentColor: netColor,
          valueColor: netColor,
        ),
        const SizedBox(height: 20),
        _RevenueBreakdownCard(
          breakdown: dashboard.revenueBreakdown,
          totalRevenue: dashboard.totalRevenue,
        ),
      ],
    );
  }
}

/// One stat card: a colored left accent bar (the mockup's visual signature
/// for this panel, in place of this app's usual icon-badge stat card — see
/// [DashboardStatCard] which doesn't fit here for that reason), a label +
/// small trailing icon, and a large bold value. No delta line — see this
/// file's top doc comment.
class _FinanceStatCard extends StatelessWidget {
  const _FinanceStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Icon(icon, size: 18, color: accentColor),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: valueColor ?? AppColors.textPrimary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One revenue category slice — real label/value pulled straight from
/// [FinanceRevenueBreakdown], paired with a color from [AppColors.accents]
/// (the app's established rotating palette for chart legends/segments).
class _RevenueSlice {
  const _RevenueSlice({required this.label, required this.rawValue, required this.color});

  final String label;
  final String rawValue;
  final Color color;

  double get amount => double.tryParse(rawValue) ?? 0;
}

/// Revenue Breakdown card: a donut chart plus a color legend, driven by the
/// same per-category figures the previous design listed as plain rows
/// (Registration/Auction/Sponsors/Other income) — no new categories
/// invented, just visualized differently.
class _RevenueBreakdownCard extends StatelessWidget {
  const _RevenueBreakdownCard({required this.breakdown, required this.totalRevenue});

  final FinanceRevenueBreakdown breakdown;
  final String totalRevenue;

  @override
  Widget build(BuildContext context) {
    final slices = <_RevenueSlice>[
      _RevenueSlice(
        label: 'Registration',
        rawValue: breakdown.registrationRevenue,
        color: AppColors.accents[0],
      ),
      _RevenueSlice(
        label: 'Auction',
        rawValue: breakdown.auctionRevenue,
        color: AppColors.accents[1],
      ),
      _RevenueSlice(
        label: 'Sponsorship',
        rawValue: breakdown.sponsorshipRevenue,
        color: AppColors.accents[2],
      ),
      _RevenueSlice(
        label: 'Other',
        rawValue: breakdown.otherIncome,
        color: AppColors.accents[3],
      ),
    ];
    final total = slices.fold<double>(0, (sum, s) => sum + s.amount);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue Breakdown', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(120, 120),
                        painter: _DonutChartPainter(
                          values: [for (final s in slices) s.amount],
                          colors: [for (final s in slices) s.color],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: FittedBox(
                              child: Text(
                                formatInr(totalRevenue),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      for (final slice in slices) ...[
                        _LegendRow(slice: slice, total: total),
                        if (slice != slices.last) const SizedBox(height: 10),
                      ],
                    ],
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

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.total});

  final _RevenueSlice slice;
  final double total;

  @override
  Widget build(BuildContext context) {
    final percent = total > 0 ? (slice.amount / total * 100).round() : 0;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slice.label,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          formatInr(slice.rawValue),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Draws a proportional donut ring from [values] (paired 1:1 with
/// [colors]) — a stroked circle split into arcs by each value's share of
/// the total, starting at 12 o'clock. Falls back to a flat grey ring when
/// every value is zero (no revenue recorded yet) rather than dividing by
/// zero or drawing nothing.
class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  static const _strokeWidth = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final total = values.fold<double>(0, (sum, v) => sum + v);

    if (total <= 0) {
      final emptyPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = AppColors.border;
      canvas.drawArc(arcRect, 0, 2 * pi, false, emptyPaint);
      return;
    }

    var startAngle = -pi / 2;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value <= 0) continue;
      final sweepAngle = (value / total) * 2 * pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..color = colors[i];
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}
