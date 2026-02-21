import 'dart:math' as math;
import 'package:flutter/material.dart';

class MangroveDashboard extends StatefulWidget {
  const MangroveDashboard({super.key});

  @override
  State<MangroveDashboard> createState() => _MangroveDashboardState();
}

class _MangroveDashboardState extends State<MangroveDashboard> {
  static const Color caribbeanGreen = Color(0xFF00DF81);
  static const Color antiFlashWhite = Color(0xFFF1F7F6);
  static const Color bangladeshGreen = Color(0xFF03624C);
  static const Color darkGreen = Color(0xFF032221);
  static const Color richBlack = Color(0xFF021B1A);
  static const List<String> _monthAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  double anchorHigh = 0.85;
  double anchorLow = 0.10;
  double erosion = 0.12;
  double damage = 0.05;
  double necrosis = 0.08;
  bool isHighTide = false;
  int totalTreesAssessed = 124;

  String? activeTab;
  int? selectedRadarIndex;
  Offset? tooltipPosition;
  String selectedTrendKey = 'ri';
  int? selectedTrendPointIndex;
  int? selectedNecrosisPointIndex;

  double get structuralScore {
    final structural = (anchorHigh * 100) + (anchorLow * 60) - (erosion * 50) - (damage * 90);
    return math.min(math.max(structural, 0), 100);
  }

  double get healthScore {
    final health = (1 - necrosis) * 100;
    return math.min(math.max(health, 0), 100);
  }

  double get resilienceIndex {
    final finalScore = structuralScore * (healthScore / 100);
    return math.min(math.max(finalScore, 0), 100);
  }

  double get mangroveTreeConfidence {
    final confidence = (anchorHigh + (1 - erosion) + (1 - damage) + (1 - necrosis)) / 4;
    return confidence.clamp(0, 1).toDouble();
  }

  Color getStatusColor(double ri) {
    if (ri >= 71) return caribbeanGreen;
    if (ri >= 41) return const Color(0xFFEAB308);
    return const Color(0xFFEF4444);
  }

  List<Map<String, dynamic>> get radarAxes => [
    {'label': 'Stability', 'value': structuralScore, 'desc': 'Physical strength and anchoring support (S).'},
    {'label': 'Health', 'value': healthScore, 'desc': 'Canopy vitality and disease burden (H).'},
    {'label': 'Resilience', 'value': resilienceIndex, 'desc': 'Final resilience index (RI).'},
  ];

  List<String> _lastMonthLabels(int count) {
    final now = DateTime.now();
    return List<String>.generate(count, (i) {
      final monthDate = DateTime(now.year, now.month - (count - 1 - i));
      return _monthAbbr[monthDate.month - 1];
    });
  }

  List<Map<String, dynamic>> get historicalScans {
    final labels = _lastMonthLabels(6);
    final sValues = [58.0, 64.0, 70.0, 74.0, 79.0, structuralScore];
    final hValues = [49.0, 56.0, 63.0, 71.0, 84.0, healthScore];
    final riValues = [28.4, 35.8, 44.1, 52.5, 66.4, resilienceIndex];
    return List<Map<String, dynamic>>.generate(
      labels.length,
      (i) => {'date': labels[i], 's': sValues[i], 'h': hValues[i], 'ri': riValues[i]},
    );
  }

  List<Map<String, dynamic>> get necrosisHistory {
    final labels = _lastMonthLabels(6);
    final values = [0.24, 0.20, 0.17, 0.14, 0.11, necrosis];
    return List<Map<String, dynamic>>.generate(
      labels.length,
      (i) => {'date': labels[i], 'n': values[i]},
    );
  }

  String get necrosisStatus {
    if (necrosis <= 0.10) return 'Low';
    if (necrosis <= 0.25) return 'Moderate';
    return 'Severe';
  }

  Color get necrosisStatusColor {
    if (necrosis <= 0.10) return caribbeanGreen;
    if (necrosis <= 0.25) return const Color(0xFFEAB308);
    return const Color(0xFFEF4444);
  }

  Map<String, double> _polarToCartesian(double centerX, double centerY, double radius, double angleInDegrees) {
    final angleInRadians = (angleInDegrees - 90) * math.pi / 180.0;
    return {'x': centerX + (radius * math.cos(angleInRadians)), 'y': centerY + (radius * math.sin(angleInRadians))};
  }

  double _clampDouble(double value, double min, double max) {
    return value.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopStatsBar(),
            const SizedBox(height: 14),
            _buildStabilityScore(),
            const SizedBox(height: 14),
            _buildBiomechanicalRadar(),
            const SizedBox(height: 14),
            _buildLongitudinalTrendLines(),
            const SizedBox(height: 14),
            _buildDynamicNecrosisCard(),
            const SizedBox(height: 14),
            _buildProbabilityBars(),
            const SizedBox(height: 14),
            _buildActionVerdict(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStatsBar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 120,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(16), border: Border.all(color: bangladeshGreen)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bar_chart, size: 16, color: Color(0xFF34D399)),
                  const SizedBox(height: 4),
                  const Text('MONITORING LOG', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: antiFlashWhite)),
                  Text('#${totalTreesAssessed + 1}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: caribbeanGreen)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 120,
            child: GestureDetector(
              onTap: () => setState(() => isHighTide = !isHighTide),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(16), border: Border.all(color: bangladeshGreen)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isHighTide ? Colors.blue.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(isHighTide ? 'SUBMERGED' : 'OPTIMAL VISIBILITY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isHighTide ? Colors.blue : Colors.green)),
                    ),
                    const SizedBox(height: 4),
                    const Text('TIDAL CONTEXT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: antiFlashWhite)),
                    Text(isHighTide ? 'High Tide' : 'Low Tide', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: caribbeanGreen)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStabilityScore() {
    return GestureDetector(
      onTap: () => setState(() => activeTab = activeTab == 'score' ? null : 'score'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(24), border: Border.all(color: bangladeshGreen), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Icon(Icons.bolt, size: 16, color: caribbeanGreen),
                  SizedBox(width: 8),
                  Text('RESILIENCE GAUGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 3, color: antiFlashWhite)),
                ]),
                Icon(activeTab == 'score' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: antiFlashWhite.withValues(alpha: 0.4)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -math.pi / 2,
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: _CircularProgressPainter(progress: resilienceIndex / 100, progressColor: getStatusColor(resilienceIndex), backgroundColor: bangladeshGreen.withValues(alpha: 0.3), strokeWidth: 16),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(resilienceIndex.toStringAsFixed(0), style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: getStatusColor(resilienceIndex))),
                      const Text('RESILIENCE INDEX', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: antiFlashWhite)),
                    ],
                  ),
                ],
              ),
            ),
            if (activeTab == 'score') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.info_outline, size: 12, color: Color(0xFF34D399)),
                      SizedBox(width: 6),
                      Text('RI BANDS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF34D399))),
                    ]),
                    const SizedBox(height: 8),
                    Text('0-40: Critical Risk  |  41-70: Vulnerable  |  71-100: Resilient', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: antiFlashWhite.withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    Text('RI combines physical stability (S) and biological vitality (H).', style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: antiFlashWhite.withValues(alpha: 0.4))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBiomechanicalRadar() {
    return GestureDetector(
      onTap: () => setState(() => activeTab = activeTab == 'radar' ? null : 'radar'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(24), border: Border.all(color: bangladeshGreen)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(children: [
                  Icon(Icons.radar, size: 16, color: caribbeanGreen),
                  SizedBox(width: 8),
                  Text('COMPARISON RADAR (S VS H)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: antiFlashWhite)),
                ]),
                Icon(activeTab == 'radar' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: antiFlashWhite.withValues(alpha: 0.4)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 260,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
                  const double tooltipWidth = 150;
                  const double tooltipHeight = 30;
                  return Center(
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTapDown: (details) => _handleRadarTap(details, size),
                            child: CustomPaint(
                              size: Size(size, size),
                              painter: _RadarChartPainter(axes: radarAxes, selectedIndex: selectedRadarIndex, gridColor: bangladeshGreen, fillColor: caribbeanGreen, lineColor: caribbeanGreen),
                            ),
                          ),
                          if (selectedRadarIndex != null && tooltipPosition != null)
                            Positioned(
                              left: _clampDouble(tooltipPosition!.dx - 60, 0, size - tooltipWidth),
                              top: _clampDouble(tooltipPosition!.dy - 40, 0, size - tooltipHeight),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: caribbeanGreen.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: caribbeanGreen, width: 1.5),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                                ),
                                child: Text('${radarAxes[selectedRadarIndex!]['label']}: ${(radarAxes[selectedRadarIndex!]['value'] as double).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: richBlack)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(selectedRadarIndex != null ? 'Tap another point to see different value' : 'Tap on a data point to see its value', style: TextStyle(fontSize: 9, color: antiFlashWhite.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Text('Shape guide: wider toward Stability = strong roots but stressed canopy. Wider toward Health = healthy canopy but weak support.', style: TextStyle(fontSize: 9, color: antiFlashWhite.withValues(alpha: 0.5))),
            if (activeTab == 'radar') ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                child: Column(children: radarAxes.asMap().entries.map((e) => _buildRadarDetailRow(index: e.key, label: e.value['label'], value: e.value['value'], desc: e.value['desc'])).toList()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleRadarTap(TapDownDetails details, double chartSize) {
    final center = chartSize / 2;
    final radius = chartSize / 2 - 20;
    final tapX = details.localPosition.dx - center;
    final tapY = details.localPosition.dy - center;
    int? closestIndex;
    double minDistance = double.infinity;
    for (var i = 0; i < radarAxes.length; i++) {
      final axisAngle = i * (360 / radarAxes.length);
      final axisValue = (radarAxes[i]['value'] as double) / 100;
      final axisRadius = radius * axisValue;
      final axisAngleRad = (axisAngle - 90) * math.pi / 180;
      final axisX = axisRadius * math.cos(axisAngleRad);
      final axisY = axisRadius * math.sin(axisAngleRad);
      final dist = math.sqrt((tapX - axisX) * (tapX - axisX) + (tapY - axisY) * (tapY - axisY));
      if (dist < 30 && dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }
    setState(() {
      if (closestIndex != null) {
        selectedRadarIndex = closestIndex;
        tooltipPosition = details.localPosition;
      } else {
        selectedRadarIndex = selectedRadarIndex == null ? 0 : (selectedRadarIndex! + 1) % radarAxes.length;
        tooltipPosition = details.localPosition;
      }
    });
  }

  void _handleTrendTap(TapDownDetails details, double chartWidth, double chartHeight) {
    const leftPad = 34.0;
    const rightPad = 24.0;
    const topPad = 20.0;
    const bottomPad = 28.0;
    final w = chartWidth - (leftPad + rightPad);
    final h = chartHeight - (topPad + bottomPad);
    final origin = Offset(leftPad, topPad);
    final tap = details.localPosition;
    final key = selectedTrendKey;
    int? closestIndex;
    double minDistance = double.infinity;
    for (int i = 0; i < historicalScans.length; i++) {
      final x = origin.dx + (w * i / (historicalScans.length - 1));
      final y = origin.dy + h - (((historicalScans[i][key] as double) / 100) * h);
      final distance = math.sqrt(math.pow(tap.dx - x, 2) + math.pow(tap.dy - y, 2));
      if (distance < 18 && distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    setState(() {
      selectedTrendPointIndex = closestIndex;
    });
  }

  void _handleNecrosisTap(TapDownDetails details, double chartWidth, double chartHeight) {
    const leftPad = 34.0;
    const rightPad = 16.0;
    const topPad = 14.0;
    const bottomPad = 26.0;
    final w = chartWidth - (leftPad + rightPad);
    final h = chartHeight - (topPad + bottomPad);
    final origin = Offset(leftPad, topPad);
    final tap = details.localPosition;
    int? closestIndex;
    double minDistance = double.infinity;
    for (int i = 0; i < necrosisHistory.length; i++) {
      final x = origin.dx + (w * i / (necrosisHistory.length - 1));
      final n = (necrosisHistory[i]['n'] as double).clamp(0.0, 1.0);
      final y = origin.dy + h - (n * h);
      final distance = math.sqrt(math.pow(tap.dx - x, 2) + math.pow(tap.dy - y, 2));
      if (distance < 18 && distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }
    setState(() {
      selectedNecrosisPointIndex = closestIndex;
    });
  }

  Widget _buildLongitudinalTrendLines() {
    const trendChipWidth = 132.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(24), border: Border.all(color: bangladeshGreen)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.show_chart, size: 16, color: caribbeanGreen),
            SizedBox(width: 8),
            Text('LONGITUDINAL TREND LINES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: antiFlashWhite)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _handleTrendTap(details, constraints.maxWidth, 170),
                  child: CustomPaint(
                    painter: _TrendLinesPainter(
                      data: historicalScans,
                      gridColor: bangladeshGreen,
                      stabilityColor: const Color(0xFF22C55E),
                      healthColor: const Color(0xFFEAB308),
                      resilienceColor: const Color(0xFF38BDF8),
                      selectedKey: selectedTrendKey,
                      selectedPointIndex: selectedTrendPointIndex,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLegendChip(
                'Stability',
                const Color(0xFF22C55E),
                fixedWidth: trendChipWidth,
                selected: selectedTrendKey == 's',
                onTap: () => setState(() {
                  selectedTrendKey = 's';
                  selectedTrendPointIndex = null;
                }),
              ),
              _buildLegendChip(
                'Health',
                const Color(0xFFEAB308),
                fixedWidth: trendChipWidth,
                selected: selectedTrendKey == 'h',
                onTap: () => setState(() {
                  selectedTrendKey = 'h';
                  selectedTrendPointIndex = null;
                }),
              ),
              _buildLegendChip(
                'Resilience Index',
                const Color(0xFF38BDF8),
                bold: true,
                fixedWidth: trendChipWidth,
                selected: selectedTrendKey == 'ri',
                onTap: () => setState(() {
                  selectedTrendKey = 'ri';
                  selectedTrendPointIndex = null;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicNecrosisCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(24), border: Border.all(color: bangladeshGreen)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.monitor_heart, size: 16, color: caribbeanGreen),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text('DYNAMIC NECROSIS', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: antiFlashWhite)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: necrosisStatusColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999), border: Border.all(color: necrosisStatusColor.withValues(alpha: 0.55))),
                child: Text(necrosisStatus.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: necrosisStatusColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _handleNecrosisTap(details, constraints.maxWidth, 130),
                  child: CustomPaint(
                    painter: _NecrosisTrendPainter(
                      data: necrosisHistory,
                      gridColor: bangladeshGreen,
                      lineColor: const Color(0xFFEF4444),
                      selectedPointIndex: selectedNecrosisPointIndex,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current necrosis: ${(necrosis * 100).toStringAsFixed(1)}% of canopy',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: antiFlashWhite.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendChip(String label, Color color, {bool bold = false, bool selected = false, VoidCallback? onTap, double? fixedWidth}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: fixedWidth,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: selected ? 0.9 : 0.6)),
          ),
          child: Row(children: [
            Container(width: bold ? 10 : 8, height: bold ? 10 : 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 8.8, fontWeight: (bold || selected) ? FontWeight.w900 : FontWeight.w700, color: antiFlashWhite),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildRadarDetailRow({required int index, required String label, required double value, required String desc}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: caribbeanGreen, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: caribbeanGreen)),
                    Text('${value.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: caribbeanGreen)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: value / 100, backgroundColor: Colors.black.withValues(alpha: 0.4), valueColor: AlwaysStoppedAnimation<Color>(_getBarColor(value)), minHeight: 6),
                ),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 9, color: antiFlashWhite.withValues(alpha: 0.5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBarColor(double value) {
    if (value >= 75) return caribbeanGreen;
    if (value >= 50) return const Color(0xFFEAB308);
    return const Color(0xFFEF4444);
  }

  Widget _buildProbabilityBars() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(24), border: Border.all(color: bangladeshGreen)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.analytics, size: 16, color: caribbeanGreen),
            SizedBox(width: 8),
            Text('AI CLASS PROBABILITIES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: antiFlashWhite)),
          ]),
          const SizedBox(height: 20),
          _buildProbabilityBar(label: 'Mangrove Tree', value: mangroveTreeConfidence, color: caribbeanGreen),
          _buildProbabilityBar(label: 'PropRoot', value: anchorHigh, color: caribbeanGreen),
          _buildProbabilityBar(label: 'Healthy Leaf', value: (1 - necrosis).clamp(0, 1).toDouble(), color: caribbeanGreen),
          _buildProbabilityBar(label: 'Necrosis', value: necrosis, color: const Color(0xFFEF4444), isNegative: true),
        ],
      ),
    );
  }

  Widget _buildProbabilityBar({required String label, required double value, required Color color, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isNegative ? const Color(0xFFFCA5A5) : antiFlashWhite.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(value * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isNegative ? const Color(0xFFFCA5A5) : caribbeanGreen)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: value, backgroundColor: Colors.black.withValues(alpha: 0.4), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 8)),
        ],
      ),
    );
  }

  Widget _buildActionVerdict() {
    final isStable = resilienceIndex >= 71;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: darkGreen, borderRadius: BorderRadius.circular(20), border: Border(left: BorderSide(color: getStatusColor(resilienceIndex), width: 4)), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 2))]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
            child: isStable ? const Icon(Icons.shield, size: 20, color: caribbeanGreen) : const Icon(Icons.warning, size: 20, color: Color(0xFFEF4444)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(isStable ? 'Resilient: high anchoring density and healthy canopy.' : 'Critical/Vulnerable: inspect weak anchoring zones and disease stress.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: antiFlashWhite.withValues(alpha: 0.82)))),
        ],
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;
  _CircularProgressPainter({required this.progress, required this.progressColor, required this.backgroundColor, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    canvas.drawCircle(center, radius, Paint()..color = backgroundColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, Paint()..color = progressColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.progressColor != progressColor;
}

class _RadarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> axes;
  final int? selectedIndex;
  final Color gridColor;
  final Color fillColor;
  final Color lineColor;
  _RadarChartPainter({required this.axes, this.selectedIndex, required this.gridColor, required this.fillColor, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final gridPaint = Paint()..color = gridColor.withValues(alpha: 0.2)..strokeWidth = 1..style = PaintingStyle.stroke;
    for (final m in [0.2, 0.4, 0.6, 0.8, 1.0]) _drawPolygon(canvas, center, radius * m, gridPaint, axes.length);
    final axisPaint = Paint()..color = gridColor.withValues(alpha: 0.2)..strokeWidth = 1;
    for (var i = 0; i < axes.length; i++) {
      final angle = i * (360 / axes.length) - 90;
      final endPoint = _polarToCartesian(center.dx, center.dy, radius, angle);
      canvas.drawLine(center, endPoint, axisPaint);
    }
    final dataPath = Path();
    for (var i = 0; i < axes.length; i++) {
      final value = (axes[i]['value'] as double) / 100;
      final angle = i * (360 / axes.length) - 90;
      final point = _polarToCartesian(center.dx, center.dy, radius * value, angle);
      if (i == 0) { dataPath.moveTo(point.dx, point.dy); } else { dataPath.lineTo(point.dx, point.dy); }
    }
    dataPath.close();
    canvas.drawPath(dataPath, Paint()..color = fillColor.withValues(alpha: 0.2)..style = PaintingStyle.fill);
    canvas.drawPath(dataPath, Paint()..color = lineColor..strokeWidth = 2..style = PaintingStyle.stroke);
    final textPainter = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    for (var i = 0; i < axes.length; i++) {
      final value = (axes[i]['value'] as double) / 100;
      final angle = i * (360 / axes.length) - 90;
      final point = _polarToCartesian(center.dx, center.dy, radius * value, angle);
      final labelPoint = _polarToCartesian(center.dx, center.dy, radius + 15, angle);
      canvas.drawCircle(Offset(point.dx, point.dy), selectedIndex == i ? 6 : 4, Paint()..color = selectedIndex == i ? fillColor : lineColor..style = PaintingStyle.fill);
      textPainter.text = TextSpan(text: (axes[i]['label'] as String).substring(0, 1), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: gridColor.withValues(alpha: 0.6)));
      textPainter.layout();
      textPainter.paint(canvas, Offset(labelPoint.dx - textPainter.width / 2, labelPoint.dy - textPainter.height / 2));
    }
  }

  Offset _polarToCartesian(double centerX, double centerY, double radius, double angleInDegrees) {
    final angleInRadians = angleInDegrees * math.pi / 180.0;
    return Offset(centerX + (radius * math.cos(angleInRadians)), centerY + (radius * math.sin(angleInRadians)));
  }

  void _drawPolygon(Canvas canvas, Offset center, double radius, Paint paint, int sides) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = i * (360 / sides) - 90.0;
      final point = _polarToCartesian(center.dx, center.dy, radius, angle);
      if (i == 0) { path.moveTo(point.dx, point.dy); } else { path.lineTo(point.dx, point.dy); }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) => oldDelegate.selectedIndex != selectedIndex || oldDelegate.axes != axes;
}

class _TrendLinesPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Color gridColor;
  final Color stabilityColor;
  final Color healthColor;
  final Color resilienceColor;
  final String selectedKey;
  final int? selectedPointIndex;
  _TrendLinesPainter({required this.data, required this.gridColor, required this.stabilityColor, required this.healthColor, required this.resilienceColor, required this.selectedKey, this.selectedPointIndex});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 34.0;
    const rightPad = 24.0;
    const topPad = 20.0;
    const bottomPad = 28.0;
    final w = size.width - (leftPad + rightPad);
    final h = size.height - (topPad + bottomPad);
    final origin = Offset(leftPad, topPad);
    final gridPaint = Paint()..color = gridColor.withValues(alpha: 0.14)..strokeWidth = 1;
    final yTickPainter = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.right);
    for (int i = 0; i <= 5; i++) {
      final y = origin.dy + (h * i / 5);
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + w, y), gridPaint);
      final tickValue = 100 - (i * 20);
      yTickPainter.text = TextSpan(
        text: '$tickValue%',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: gridColor.withValues(alpha: 0.75)),
      );
      yTickPainter.layout();
      yTickPainter.paint(canvas, Offset(origin.dx - yTickPainter.width - 6, y - yTickPainter.height / 2));
    }
    canvas.drawRect(Rect.fromLTWH(origin.dx, origin.dy, w, h), Paint()..color = Colors.transparent..style = PaintingStyle.stroke..strokeWidth = 1..color = gridColor.withValues(alpha: 0.25));

    List<Offset> linePoints(String key) {
      return List<Offset>.generate(data.length, (i) {
        final x = origin.dx + (w * i / (data.length - 1));
        final y = origin.dy + h - ((data[i][key] as double) / 100 * h);
        return Offset(x, y);
      });
    }

    Path smoothPath(List<Offset> points) {
      final path = Path();
      if (points.isEmpty) return path;
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final cx = (prev.dx + curr.dx) / 2;
        path.cubicTo(cx, prev.dy, cx, curr.dy, curr.dx, curr.dy);
      }
      return path;
    }

    final sPoints = linePoints('s');
    final hPoints = linePoints('h');
    final riPoints = linePoints('ri');
    final selectedPoints = selectedKey == 's' ? sPoints : (selectedKey == 'h' ? hPoints : riPoints);
    final selectedColor = selectedKey == 's' ? stabilityColor : (selectedKey == 'h' ? healthColor : resilienceColor);
    final selectedPath = smoothPath(selectedPoints);

    for (int i = 0; i < data.length; i++) {
      final x = origin.dx + (w * i / (data.length - 1));
      canvas.drawLine(
        Offset(x, origin.dy),
        Offset(x, origin.dy + h),
        Paint()..color = gridColor.withValues(alpha: 0.08)..strokeWidth = 1,
      );
    }

    final fillPath = Path.from(selectedPath)
      ..lineTo(selectedPoints.last.dx, origin.dy + h)
      ..lineTo(selectedPoints.first.dx, origin.dy + h)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            selectedColor.withValues(alpha: 0.28),
            selectedColor.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromLTWH(origin.dx, origin.dy, w, h))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      smoothPath(sPoints),
      Paint()..color = stabilityColor.withValues(alpha: 0.16)..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      smoothPath(hPoints),
      Paint()..color = healthColor.withValues(alpha: 0.16)..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      selectedPath,
      Paint()..color = selectedColor.withValues(alpha: 0.20)..style = PaintingStyle.stroke..strokeWidth = 6.5..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      selectedPath,
      Paint()..color = selectedColor..style = PaintingStyle.stroke..strokeWidth = 2.3..strokeCap = StrokeCap.round,
    );

    if (selectedPointIndex != null) {
      final highlightIndex = selectedPointIndex!.clamp(0, data.length - 1);
      final highlightX = origin.dx + (w * highlightIndex / (data.length - 1));
      final selectedValue = data[highlightIndex][selectedKey] as double;
      final highlightY = origin.dy + h - (selectedValue / 100 * h);
      canvas.drawLine(
        Offset(highlightX, origin.dy),
        Offset(highlightX, origin.dy + h),
        Paint()..color = selectedColor.withValues(alpha: 0.30)..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(highlightX, highlightY), 5.2, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(highlightX, highlightY), 3.2, Paint()..color = selectedColor);

      final calloutX = (highlightX + 10).clamp(origin.dx + 4, origin.dx + w - 122);
      final calloutY = (highlightY - 58).clamp(origin.dy + 4, origin.dy + h - 52);
      final calloutRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(calloutX, calloutY, 118, 52),
        const Radius.circular(8),
      );
      canvas.drawRRect(calloutRect, Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.95));
      canvas.drawRRect(
        calloutRect,
        Paint()..color = Colors.white.withValues(alpha: 0.10)..style = PaintingStyle.stroke,
      );
      final calloutPainter = TextPainter(textDirection: TextDirection.ltr);
      calloutPainter.text = TextSpan(
        text: '${data[highlightIndex]['date']}  •  ${selectedValue.toStringAsFixed(1)}%',
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
      );
      calloutPainter.layout(maxWidth: 110);
      calloutPainter.paint(canvas, Offset(calloutX + 6, calloutY + 6));
      calloutPainter.text = TextSpan(
        text: 'S ${data[highlightIndex]['s'].toStringAsFixed(1)}  H ${data[highlightIndex]['h'].toStringAsFixed(1)}',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85)),
      );
      calloutPainter.layout(maxWidth: 110);
      calloutPainter.paint(canvas, Offset(calloutX + 6, calloutY + 22));
      calloutPainter.text = TextSpan(
        text: '${selectedKey.toUpperCase()} ${selectedValue.toStringAsFixed(1)}',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: selectedColor),
      );
      calloutPainter.layout(maxWidth: 110);
      calloutPainter.paint(canvas, Offset(calloutX + 6, calloutY + 36));
    }

    final xTickPainter = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    for (int i = 0; i < data.length; i++) {
      final x = origin.dx + (w * i / (data.length - 1));
      final month = (data[i]['date'] as String?) ?? '';
      xTickPainter.text = TextSpan(
        text: month,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: gridColor.withValues(alpha: 0.8)),
      );
      xTickPainter.layout();
      xTickPainter.paint(canvas, Offset(x - xTickPainter.width / 2, origin.dy + h + 6));
    }

    final yAxisLabelPainter = TextPainter(
      text: TextSpan(
        text: 'Score (%)',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: gridColor.withValues(alpha: 0.9)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    yAxisLabelPainter.paint(
      canvas,
      Offset(origin.dx - yAxisLabelPainter.width - 8, origin.dy - yAxisLabelPainter.height - 10),
    );

    final xAxisLabelPainter = TextPainter(
      text: TextSpan(
        text: 'Month',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: gridColor.withValues(alpha: 0.9)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    xAxisLabelPainter.paint(canvas, Offset(origin.dx + w - xAxisLabelPainter.width, origin.dy + h + 18));
  }

  @override
  bool shouldRepaint(covariant _TrendLinesPainter oldDelegate) => oldDelegate.data != data || oldDelegate.selectedKey != selectedKey || oldDelegate.selectedPointIndex != selectedPointIndex;
}

class _NecrosisTrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Color gridColor;
  final Color lineColor;
  final int? selectedPointIndex;
  _NecrosisTrendPainter({required this.data, required this.gridColor, required this.lineColor, this.selectedPointIndex});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 34.0;
    const rightPad = 16.0;
    const topPad = 14.0;
    const bottomPad = 26.0;
    final w = size.width - (leftPad + rightPad);
    final h = size.height - (topPad + bottomPad);
    final origin = Offset(leftPad, topPad);
    final gridPaint = Paint()..color = gridColor.withValues(alpha: 0.25)..strokeWidth = 1;
    final yTickPainter = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.right);
    for (int i = 0; i <= 4; i++) {
      final y = origin.dy + (h * i / 4);
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + w, y), gridPaint);
      final tickValue = 100 - (i * 25);
      yTickPainter.text = TextSpan(
        text: '$tickValue%',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: gridColor.withValues(alpha: 0.75)),
      );
      yTickPainter.layout();
      yTickPainter.paint(canvas, Offset(origin.dx - yTickPainter.width - 6, y - yTickPainter.height / 2));
    }

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = origin.dx + (w * i / (data.length - 1));
      final n = (data[i]['n'] as double).clamp(0.0, 1.0);
      final y = origin.dy + h - (n * h);
      points.add(Offset(x, y));
    }

    Path smoothPath(List<Offset> points) {
      final path = Path();
      if (points.isEmpty) return path;
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final cx = (prev.dx + curr.dx) / 2;
        path.cubicTo(cx, prev.dy, cx, curr.dy, curr.dx, curr.dy);
      }
      return path;
    }

    final trendPath = smoothPath(points);
    final fillPath = Path.from(trendPath)
      ..lineTo(points.last.dx, origin.dy + h)
      ..lineTo(points.first.dx, origin.dy + h)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromLTWH(origin.dx, origin.dy, w, h))
        ..style = PaintingStyle.fill,
    );

    for (int i = 0; i < data.length; i++) {
      final x = origin.dx + (w * i / (data.length - 1));
      canvas.drawLine(
        Offset(x, origin.dy),
        Offset(x, origin.dy + h),
        Paint()..color = gridColor.withValues(alpha: 0.08)..strokeWidth = 1,
      );
    }

    canvas.drawPath(
      trendPath,
      Paint()..color = lineColor.withValues(alpha: 0.20)..style = PaintingStyle.stroke..strokeWidth = 6.0..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      trendPath,
      Paint()..color = lineColor..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round,
    );

    final dotPaint = Paint()..color = lineColor.withValues(alpha: 0.5);
    for (int i = 0; i < data.length; i++) {
      final x = origin.dx + (w * i / (data.length - 1));
      final n = (data[i]['n'] as double).clamp(0.0, 1.0);
      final y = origin.dy + h - (n * h);
      canvas.drawCircle(Offset(x, y), 2, dotPaint);
    }

    if (selectedPointIndex != null) {
      final index = selectedPointIndex!.clamp(0, data.length - 1);
      final x = origin.dx + (w * index / (data.length - 1));
      final n = (data[index]['n'] as double).clamp(0.0, 1.0);
      final y = origin.dy + h - (n * h);
      final necrosisPct = n * 100;
      canvas.drawLine(
        Offset(x, origin.dy),
        Offset(x, origin.dy + h),
        Paint()..color = lineColor.withValues(alpha: 0.30)..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 5.0, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, y), 3.0, Paint()..color = lineColor);

      final calloutX = (x + 8).clamp(origin.dx + 4, origin.dx + w - 114);
      final calloutY = (y - 44).clamp(origin.dy + 4, origin.dy + h - 40);
      final calloutRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(calloutX, calloutY, 110, 38),
        const Radius.circular(8),
      );
      canvas.drawRRect(calloutRect, Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.95));
      canvas.drawRRect(
        calloutRect,
        Paint()..color = Colors.white.withValues(alpha: 0.10)..style = PaintingStyle.stroke,
      );
      final calloutPainter = TextPainter(textDirection: TextDirection.ltr);
      calloutPainter.text = TextSpan(
        text: '${data[index]['date']}  •  ${necrosisPct.toStringAsFixed(1)}%',
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
      );
      calloutPainter.layout(maxWidth: 102);
      calloutPainter.paint(canvas, Offset(calloutX + 6, calloutY + 7));
      calloutPainter.text = TextSpan(
        text: 'Necrosis ${necrosisPct.toStringAsFixed(1)}%',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: lineColor),
      );
      calloutPainter.layout(maxWidth: 102);
      calloutPainter.paint(canvas, Offset(calloutX + 6, calloutY + 21));
    }

    final xTickPainter = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    for (int i = 0; i < data.length; i++) {
      final x = origin.dx + (w * i / (data.length - 1));
      final month = (data[i]['date'] as String?) ?? '';
      xTickPainter.text = TextSpan(
        text: month,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: gridColor.withValues(alpha: 0.8)),
      );
      xTickPainter.layout();
      xTickPainter.paint(canvas, Offset(x - xTickPainter.width / 2, origin.dy + h + 5));
    }

    final yAxisLabelPainter = TextPainter(
      text: TextSpan(
        text: 'Necrosis (%)',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: gridColor.withValues(alpha: 0.9)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    yAxisLabelPainter.paint(
      canvas,
      Offset(origin.dx - yAxisLabelPainter.width - 2, origin.dy - yAxisLabelPainter.height - 4),
    );

    final xAxisLabelPainter = TextPainter(
      text: TextSpan(
        text: 'Month',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: gridColor.withValues(alpha: 0.9)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    xAxisLabelPainter.paint(canvas, Offset(origin.dx + w - xAxisLabelPainter.width, origin.dy + h + 16));
  }

  @override
  bool shouldRepaint(covariant _NecrosisTrendPainter oldDelegate) => oldDelegate.data != data || oldDelegate.lineColor != lineColor || oldDelegate.selectedPointIndex != selectedPointIndex;
}
