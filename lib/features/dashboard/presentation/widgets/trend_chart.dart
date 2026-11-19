import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/surface_card.dart';
import '../../domain/dashboard_models.dart';

/// Gráfica de línea con título y estado vacío propio (sin datos de ejemplo).
class TrendChart extends StatelessWidget {
  const TrendChart({
    required this.title,
    required this.points,
    required this.emptyText,
    required this.color,
    required this.axisLabel,
    required this.valueLabel,
    super.key,
  });

  final String title;
  final List<ChartPoint> points;
  final String emptyText;
  final Color color;

  /// Texto del eje X para un instante (fecha u hora).
  final String Function(DateTime at) axisLabel;

  /// Texto de un valor con su unidad, p. ej. "24,1 °C".
  final String Function(double value) valueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (points.isNotEmpty)
                Text(
                  valueLabel(points.last.value),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (points.isEmpty)
            SizedBox(
              height: 112,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.show_chart_rounded, size: 32, color: muted),
                    const SizedBox(height: 8),
                    Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(height: 160, child: _chart(theme, muted)),
        ],
      ),
    );
  }

  Widget _chart(ThemeData theme, Color muted) {
    const msPerHour = 3600000;
    final origin = points.first.at.millisecondsSinceEpoch;
    final spots = [
      for (final p in points)
        FlSpot((p.at.millisecondsSinceEpoch - origin) / msPerHour, p.value),
    ];
    final span = spots.last.x;
    final values = points.map((p) => p.value);
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final pad = high == low ? 1.0 : (high - low) * 0.2;
    final small = theme.textTheme.labelSmall?.copyWith(color: muted);

    return LineChart(
      LineChartData(
        minX: span == 0 ? -1 : 0,
        maxX: span == 0 ? 1 : span,
        minY: low - pad,
        maxY: high + pad,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) =>
                  Text(meta.formattedValue, style: small),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: math.max(span / 3, 1),
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > span) return const SizedBox.shrink();
                final at = DateTime.fromMillisecondsSinceEpoch(
                  origin + (value * msPerHour).round(),
                );
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(axisLabel(at), style: small),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem(
                  valueLabel(t.y),
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 3,
            dotData: FlDotData(show: spots.length < 3),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
