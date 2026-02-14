import 'package:flutter/material.dart';
import 'dart:math' as math;

// Color constants
const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Data state - equivalent to React useState
  double anchorHigh = 0.85;
  double anchorLow = 0.10;
  double erosion = 0.12;
  double damage = 0.05;
  double necrosis = 0.08;
  bool isHighTide = false;
  int totalTreesAssessed = 124;

  // UI state
  double score = 0;
  String? activeTab; // 'score' or 'radar'

  // Radar axes data
  List<Map<String, dynamic>> get radarAxes => [
    {'label': 'Anchoring', 'value': anchorHigh * 100, 'desc': 'Density of stilt/prop roots.'},
    {'label': 'Integrity', 'value': (1 - damage) * 100, 'desc': 'Freedom from trunk fractures.'},
    {'label': 'Soil Grip', 'value': (1 - erosion) * 100, 'desc': 'Foundation depth vs scour.'},
    {'label': 'Vigor', 'value': (1 - necrosis) * 100, 'desc': 'Chlorophyll/health of canopy.'},
    {'label': 'Redundancy', 'value': 80.0, 'desc': 'Secondary root support systems.'},
  ];

  // Calculate score - equivalent to React useEffect
  @override
  void initState() {
    super.initState();
    _calculateScore();
  }

  void _calculateScore() {
    final structural = (anchorHigh * 100) + (anchorLow * 60) - (erosion * 50) - (damage * 90);
    final multiplier = 1.0 - necrosis;
    final finalScore = structural * multiplier;
    setState(() {
      score = math.min(math.max(finalScore, 0), 100);
    });
  }

  Color getStatusColor(double s) {
    if (s >= 75) return caribbeanGreen;
    if (s >= 50) return const Color(0xFFEAB308);
    return const Color(0xFFEF4444);
  }

  // Helper for radar chart polar to cartesian
  Map<String, double> polarToCartesian(double centerX, double centerY, double radius, double angleInDegrees) {
    final angleInRadians = (angleInDegrees - 90) * math.pi / 180.0;
    return {
      'x': centerX + (radius * math.cos(angleInRadians)),
      'y': centerY + (radius * math.sin(angleInRadians)),
    };
  }

  String generateRadarPath(List<Map<String, dynamic>> axes, double radius) {
    return axes.asMap().entries.map((entry) {
      final i = entry.key;
      final axis = entry.value;
      final point = polarToCartesian(100, 100, (axis['value'] / 100) * radius, i * (360 / axes.length));
      return '${point['x']},${point['y']}';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: richBlack,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 1. TOP STATS BAR
            _buildTopStatsBar(),
            const SizedBox(height: 16),

            // 2. STABILITY SCORE (WITH DRILL-DOWN)
            _buildStabilityScore(),
            const SizedBox(height: 16),

            // 3. BIOMECHANICAL DISTRIBUTION (RADAR)
            _buildRadarSection(),
            const SizedBox(height: 16),

            // 4. PROBABILITY BARS
            _buildProbabilityBars(),
            const SizedBox(height: 16),

            // 5. ACTION VERDICT
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
        // Monitoring Log Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: darkGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bangladeshGreen),
            ),
            child: Column(
              children: [
                Icon(Icons.bar_chart, size: 16, color: caribbeanGreen.withOpacity(0.5)),
                const SizedBox(height: 4),
                Text(
                  'MONITORING LOG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: antiFlashWhite.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${totalTreesAssessed + 1}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: caribbeanGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Tidal Context Card
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                isHighTide = !isHighTide;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: darkGreen,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: bangladeshGreen),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isHighTide 
                        ? Colors.blue.withOpacity(0.2) 
                        : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isHighTide ? 'SUBMERGED' : 'OPTIMAL',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: isHighTide ? Colors.blue[300] : Colors.green[300],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TIDAL CONTEXT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: antiFlashWhite.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHighTide ? 'High Tide' : 'Low Tide',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: caribbeanGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStabilityScore() {
    return GestureDetector(
      onTap: () {
        setState(() {
          activeTab = activeTab == 'score' ? null : 'score';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: darkGreen,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: bangladeshGreen),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, size: 16, color: caribbeanGreen),
                    const SizedBox(width: 8),
                    const Text(
                      'STABILITY SCORE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: antiFlashWhite,
                      ),
                    ),
                  ],
                ),
                Icon(
                  activeTab == 'score' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: antiFlashWhite.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Circular Progress
            SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: CircularProgressPainter(
                  progress: score / 100,
                  progressColor: getStatusColor(score),
                  backgroundColor: bangladeshGreen.withOpacity(0.2),
                  strokeWidth: 16,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${score.round()}',
                        style: TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w900,
                          color: getStatusColor(score),
                        ),
                      ),
                      Text(
                        'RESILIENCE INDEX',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: antiFlashWhite.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Drill-down formula
            if (activeTab == 'score') ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 12, color: caribbeanGreen),
                        const SizedBox(width: 6),
                        const Text(
                          'CALCULATION FORMULA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: caribbeanGreen,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RI = ((AnchorHigh × 1.0) + (AnchorLow × 0.6) - (Scour × 0.5) - (Damage × 0.9)) × (1.0 - Necrosis)',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: antiFlashWhite.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Weights derived from LNU Capstone Biomechanical Study (2026).',
                      style: TextStyle(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        color: antiFlashWhite.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRadarSection() {
    return GestureDetector(
      onTap: () {
        setState(() {
          activeTab = activeTab == 'radar' ? null : 'radar';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: darkGreen,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: bangladeshGreen),
        ),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.center_focus_strong, size: 16, color: caribbeanGreen),
                    const SizedBox(width: 8),
                    const Text(
                      'BIOMECHANICAL DISTRIBUTION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: antiFlashWhite,
                      ),
                    ),
                  ],
                ),
                Icon(
                  activeTab == 'radar' ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: antiFlashWhite.withOpacity(0.4),
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Radar Chart
            SizedBox(
              width: 180,
              height: 180,
              child: CustomPaint(
                painter: RadarChartPainter(
                  axes: radarAxes,
                  primaryColor: caribbeanGreen,
                  gridColor: bangladeshGreen,
                ),
              ),
            ),

            // Drill-down axis details
            if (activeTab == 'radar') ...[
              const SizedBox(height: 16),
              ...radarAxes.map((axis) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: caribbeanGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            axis['label'].toString().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: caribbeanGreen,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            axis['desc'].toString(),
                            style: TextStyle(
                              fontSize: 9,
                              color: antiFlashWhite.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProbabilityBars() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: bangladeshGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, size: 16, color: caribbeanGreen),
              const SizedBox(width: 8),
              const Text(
                'AI CLASS PROBABILITIES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: antiFlashWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Positive indicators
          _buildProbabilityBar('High Root Density', anchorHigh, caribbeanGreen),
          const SizedBox(height: 16),
          _buildProbabilityBar('Low Root Density', anchorLow, const Color(0xFFEAB308)),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.05), thickness: 1),

          const SizedBox(height: 16),
          // Negative indicators
          _buildProbabilityBar('Substrate Scour', erosion, const Color(0xFFEF4444), isNegative: true),
          const SizedBox(height: 16),
          _buildProbabilityBar('Mechanical Damage', damage, const Color(0xFFDC2626), isNegative: true),
          const SizedBox(height: 16),
          _buildProbabilityBar('Canopy Necrosis', necrosis, const Color(0xFFF97316), isNegative: true),
        ],
      ),
    );
  }

  Widget _buildProbabilityBar(String label, double value, Color color, {bool isNegative = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isNegative ? const Color(0xFFFCA5A5) : antiFlashWhite.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isNegative ? const Color(0xFFFCA5A5) : caribbeanGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.black.withOpacity(0.4),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildActionVerdict() {
    final isGood = score >= 75;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(
            color: getStatusColor(score),
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isGood ? Icons.shield : Icons.warning,
              size: 20,
              color: isGood ? caribbeanGreen : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isGood 
                ? "Stability Confirmed: Optimal structural lock for storm surges."
                : "Structural Alert: Potential foundation/trunk failure imminent.",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: antiFlashWhite.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for Circular Progress
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.progressColor != progressColor;
  }
}

// Custom Painter for Radar Chart
class RadarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> axes;
  final Color primaryColor;
  final Color gridColor;

  RadarChartPainter({
    required this.axes,
    required this.primaryColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Draw grid circles
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, radius * (i * 0.2), gridPaint);
    }

    // Draw axis lines
    for (int i = 0; i < axes.length; i++) {
      final angle = (i * (360 / axes.length) - 90) * math.pi / 180;
      final endX = center.dx + radius * math.cos(angle);
      final endY = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(endX, endY), gridPaint);
    }

    // Draw data polygon
    final path = Path();
    final fillPaint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < axes.length; i++) {
      final value = axes[i]['value'] as double;
      final angle = (i * (360 / axes.length) - 90) * math.pi / 180;
      final distance = radius * (value / 100);
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Draw labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i < axes.length; i++) {
      final label = axes[i]['label'] as String;
      final angle = (i * (360 / axes.length) - 90) * math.pi / 180;
      final labelRadius = radius * 1.15;
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      textPainter.text = TextSpan(
        text: label.isNotEmpty ? label[0] : '',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: antiFlashWhite.withOpacity(0.4),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    return true;
  }
}

