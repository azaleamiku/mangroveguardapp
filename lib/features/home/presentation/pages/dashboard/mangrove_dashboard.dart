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

  List<Map<String, dynamic>> get historicalScans => [
    {'date': 'Sep', 's': 58.0, 'h': 49.0, 'ri': 28.4},
    {'date': 'Oct', 's': 64.0, 'h': 56.0, 'ri': 35.8},
    {'date': 'Nov', 's': 70.0, 'h': 63.0, 'ri': 44.1},
    {'date': 'Dec', 's': 74.0, 'h': 71.0, 'ri': 52.5},
    {'date': 'Jan', 's': 79.0, 'h': 84.0, 'ri': 66.4},
    {'date': 'Feb', 's': structuralScore, 'h': healthScore, 'ri': resilienceIndex},
  ];

  List<Map<String, dynamic>> get necrosisHistory => [
    {'date': 'Sep', 'n': 0.24},
    {'date': 'Oct', 'n': 0.20},
    {'date': 'Nov', 'n': 0.17},
    {'date': 'Dec', 'n': 0.14},
    {'date': 'Jan', 'n': 0.11},
    {'date': 'Feb', 'n': necrosis},
  ];

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
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopStatsBar(),
            const SizedBox(height: 16),
            _buildStabilityScore(),
            const SizedBox(height: 16),
            _buildBiomechanicalRadar(),
            const SizedBox(height: 16),
            _buildLongitudinalTrendLines(),
            const SizedBox(height: 16),
            _buildDynamicNecrosisCard(),
            const SizedBox(height: 16),
            _buildProbabilityBars(),
            const SizedBox(height: 16),
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

  Widget _buildLongitudinalTrendLines() {
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
            child: CustomPaint(painter: _TrendLinesPainter(data: historicalScans, gridColor: bangladeshGreen, stabilityColor: const Color(0xFF22C55E), healthColor: const Color(0xFFEAB308), resilienceColor: const Color(0xFF38BDF8))),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLegendChip('Stability', const Color(0xFF22C55E)),
              const SizedBox(width: 8),
              _buildLegendChip('Health', const Color(0xFFEAB308)),
              const SizedBox(width: 8),
              _buildLegendChip('Resilience Index', const Color(0xFF38BDF8), bold: true),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monitor_heart, size: 16, color: caribbeanGreen),
                  SizedBox(width: 8),
                  Text('DYNAMIC NECROSIS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.8, color: antiFlashWhite)),
                ],
              ),
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
            child: CustomPaint(
              painter: _NecrosisTrendPainter(
                data: necrosisHistory,
                gridColor: bangladeshGreen,
                lineColor: const Color(0xFFEF4444),
              ),
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

  Widget _buildLegendChip(String label, Color color, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.6))),
      child: Row(children: [
        Container(width: bold ? 10 : 8, height: bold ? 10 : 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: antiFlashWhite)),
      ]),
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
              Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isNegative ? const Color(0xFFFCA5A5) : antiFlashWhite.withValues(alpha: 0.6))),
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
          Expanded(child: Text(isStable ? 'Resilient: high anchoring density and healthy canopy.' : 'Critical/Vulnerable: inspect weak anchoring zones and disease stress.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: antiFlashWhite.withValues(alpha: 0.8)))),
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
  _TrendLinesPainter({required this.data, required this.gridColor, required this.stabilityColor, required this.healthColor, required this.resilienceColor});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 20.0;
    final w = size.width - (pad * 2);
    final h = size.height - (pad * 2);
    final origin = Offset(pad, pad);
    final gridPaint = Paint()..color = gridColor.withValues(alpha: 0.25)..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) {
      final y = origin.dy + (h * i / 5);
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + w, y), gridPaint);
    }
    canvas.drawRect(Rect.fromLTWH(origin.dx, origin.dy, w, h), Paint()..color = Colors.transparent..style = PaintingStyle.stroke..strokeWidth = 1..color = gridColor.withValues(alpha: 0.4));

    void drawLine(String key, Color color, {double stroke = 2}) {
      final path = Path();
      for (int i = 0; i < data.length; i++) {
        final x = origin.dx + (w * i / (data.length - 1));
        final y = origin.dy + h - ((data[i][key] as double) / 100 * h);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
    }

    drawLine('s', stabilityColor, stroke: 2);
    drawLine('h', healthColor, stroke: 2);
    drawLine('ri', resilienceColor, stroke: 3.5);
  }

  @override
  bool shouldRepaint(covariant _TrendLinesPainter oldDelegate) => oldDelegate.data != data;
}

class _NecrosisTrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Color gridColor;
  final Color lineColor;
  _NecrosisTrendPainter({required this.data, required this.gridColor, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 16.0;
    final w = size.width - (pad * 2);
    final h = size.height - (pad * 2);
    final origin = Offset(pad, pad);
    final gridPaint = Paint()..color = gridColor.withValues(alpha: 0.25)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = origin.dy + (h * i / 4);
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + w, y), gridPaint);
    }

    final trendPath = Path();
    for (int i = 0; i < data.length; i++) {
      final x = origin.dx + (w * i / (data.length - 1));
      final n = (data[i]['n'] as double).clamp(0.0, 1.0);
      final y = origin.dy + h - (n * h);
      if (i == 0) {
        trendPath.moveTo(x, y);
      } else {
        trendPath.lineTo(x, y);
      }
    }
    canvas.drawPath(trendPath, Paint()..color = lineColor..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);

    final dotPaint = Paint()..color = lineColor;
    for (int i = 0; i < data.length; i++) {
      final x = origin.dx + (w * i / (data.length - 1));
      final n = (data[i]['n'] as double).clamp(0.0, 1.0);
      final y = origin.dy + h - (n * h);
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NecrosisTrendPainter oldDelegate) => oldDelegate.data != data || oldDelegate.lineColor != lineColor;
}
