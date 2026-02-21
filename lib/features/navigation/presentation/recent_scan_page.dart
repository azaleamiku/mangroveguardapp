import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_header.dart';

const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

class RecentScanPage extends StatefulWidget {
  const RecentScanPage({super.key});

  @override
  State<RecentScanPage> createState() => _RecentScanPageState();
}

class _RecentScanPageState extends State<RecentScanPage> {
  bool _isHighTide = false;

  @override
  Widget build(BuildContext context) {
    const baseResilience = 66.4;
    const baseStructural = 79.0;
    const baseHealth = 84.0;
    const baseNecrosis = 8.0;
    const scanTime = 'Most recent scan: Feb 21, 2026 • 09:40 AM';
    const treeId = 'Tree #07';
    const location = 'Plot 2 • Transect B';
    const months = ['Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb'];
    const tidalCorrection = 0.92;

    final structural = _isHighTide ? (baseStructural * tidalCorrection).clamp(0, 100).toDouble() : baseStructural;
    final health = baseHealth;
    final necrosis = _isHighTide ? (baseNecrosis * 1.12).clamp(0, 100).toDouble() : baseNecrosis;
    final resilience = _isHighTide ? (baseResilience * tidalCorrection).clamp(0, 100).toDouble() : baseResilience;
    final trend = _isHighTide
        ? [31.2, 38.8, 44.3, 52.5, 57.4, 66.4].map((v) => (v * tidalCorrection).clamp(0, 100).toDouble()).toList()
        : [31.2, 38.8, 44.3, 52.5, 57.4, 66.4];

    return Scaffold(
      appBar: buildAppHeader('Recent Scan'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
        child: Column(
          children: [
            _panel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Latest Resilience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: antiFlashWhite.withValues(alpha: 0.75))),
                        const SizedBox(height: 8),
                        Text('${resilience.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: antiFlashWhite)),
                        const SizedBox(height: 6),
                        Text(scanTime, style: TextStyle(fontSize: 11, color: antiFlashWhite.withValues(alpha: 0.6))),
                        const SizedBox(height: 8),
                        Text('Scanned: $treeId', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: antiFlashWhite)),
                        Text(location, style: TextStyle(fontSize: 10, color: antiFlashWhite.withValues(alpha: 0.65))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      _isHighTide ? 'Tidal corr. x0.92 applied' : 'Baseline tide correction',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _panel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tidal Context', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: antiFlashWhite.withValues(alpha: 0.8))),
                        const SizedBox(height: 4),
                        Text(
                          _isHighTide ? 'High tide conditions selected' : 'Low tide conditions selected',
                          style: TextStyle(fontSize: 10, color: antiFlashWhite.withValues(alpha: 0.62)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _tideToggle(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resilience Gauge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: antiFlashWhite.withValues(alpha: 0.75))),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 130,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(size: const Size(130, 130), painter: _RingGaugePainter(value: resilience / 100)),
                              Text('${resilience.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: antiFlashWhite)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Scan Breakdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: antiFlashWhite.withValues(alpha: 0.75))),
                        const SizedBox(height: 10),
                        _metricLine('Structural (S)', structural, const Color(0xFF22C55E)),
                        _metricLine('Health (H)', health, const Color(0xFFEAB308)),
                        _metricLine('Necrosis', necrosis, const Color(0xFFEF4444)),
                        const SizedBox(height: 8),
                        Text('Mode: Root-first + Optional Canopy', style: TextStyle(fontSize: 10, color: antiFlashWhite.withValues(alpha: 0.65))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resilience Trend', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: antiFlashWhite.withValues(alpha: 0.75))),
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 2.5,
                    child: CustomPaint(
                      painter: _TrendPainter(
                        values: trend,
                        months: months,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rescan started for this tree profile.')),
                      );
                    },
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    label: const Text('Rescan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: antiFlashWhite,
                      side: BorderSide(color: bangladeshGreen.withValues(alpha: 0.9)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recent scan saved to local study records.')),
                      );
                    },
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Save Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: caribbeanGreen,
                      foregroundColor: richBlack,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bangladeshGreen),
      ),
      child: child,
    );
  }

  Widget _metricLine(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: antiFlashWhite.withValues(alpha: 0.8))),
              Text('${value.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0, 1),
              minHeight: 7,
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tideToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bangladeshGreen.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tideOption(label: 'Low Tide', active: !_isHighTide, onTap: () => setState(() => _isHighTide = false)),
          _tideOption(label: 'High Tide', active: _isHighTide, onTap: () => setState(() => _isHighTide = true)),
        ],
      ),
    );
  }

  Widget _tideOption({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? caribbeanGreen.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? caribbeanGreen.withValues(alpha: 0.65) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            color: active ? caribbeanGreen : antiFlashWhite.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  final double value;
  const _RingGaugePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white.withValues(alpha: 0.08)..style = PaintingStyle.stroke..strokeWidth = 12);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0, 1),
      false,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF22C55E)]).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter oldDelegate) => oldDelegate.value != value;
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final List<String> months;
  const _TrendPainter({required this.values, required this.months});

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 30.0;
    const rightPad = 12.0;
    const topPad = 10.0;
    const bottomPad = 24.0;
    final w = size.width - (leftPad + rightPad);
    final h = size.height - (topPad + bottomPad);
    final origin = Offset(leftPad, topPad);

    final grid = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 1;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final span = (maxValue - minValue).abs() < 1 ? 1.0 : (maxValue - minValue);
    final yMin = (minValue - span * 0.25).clamp(0.0, 100.0).toDouble();
    final yMax = (maxValue + span * 0.20).clamp(0.0, 100.0).toDouble();
    final yRange = (yMax - yMin).abs() < 1 ? 1.0 : (yMax - yMin);

    final yText = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.right);
    for (int i = 0; i <= 4; i++) {
      final y = origin.dy + (h * i / 4);
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + w, y), grid);
      final tickValue = yMax - ((yRange * i) / 4);
      yText.text = TextSpan(
        text: '${tickValue.toStringAsFixed(0)}%',
        style: TextStyle(fontSize: 8, color: antiFlashWhite.withValues(alpha: 0.55)),
      );
      yText.layout();
      yText.paint(canvas, Offset(origin.dx - yText.width - 6, y - yText.height / 2));
    }

    final slotWidth = w / values.length;
    final barWidth = slotWidth * 0.58;
    final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);

    for (int i = 0; i < values.length; i++) {
      final value = values[i];
      final normalized = ((value - yMin) / yRange).clamp(0.0, 1.0);
      final barHeight = normalized * h;
      final xCenter = origin.dx + (slotWidth * i) + (slotWidth / 2);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(xCenter - (barWidth / 2), origin.dy + h - barHeight, barWidth, barHeight),
        const Radius.circular(6),
      );
      final isLatest = i == values.length - 1;
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLatest
              ? [const Color(0xFF22C55E), const Color(0xFF38BDF8)]
              : [const Color(0xFF60A5FA).withValues(alpha: 0.85), const Color(0xFF60A5FA).withValues(alpha: 0.35)],
        ).createShader(barRect.outerRect);
      canvas.drawRRect(barRect, barPaint);

      tp.text = TextSpan(
        text: value.toStringAsFixed(0),
        style: TextStyle(
          fontSize: 8,
          fontWeight: isLatest ? FontWeight.w900 : FontWeight.w700,
          color: isLatest ? const Color(0xFF22C55E) : antiFlashWhite.withValues(alpha: 0.75),
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(xCenter - tp.width / 2, (origin.dy + h - barHeight - tp.height - 3).clamp(origin.dy, origin.dy + h)));

      tp.text = TextSpan(text: months[i], style: TextStyle(fontSize: 9, color: antiFlashWhite.withValues(alpha: 0.6)));
      tp.layout();
      tp.paint(canvas, Offset(xCenter - tp.width / 2, origin.dy + h + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => oldDelegate.values != values || oldDelegate.months != months;
}
