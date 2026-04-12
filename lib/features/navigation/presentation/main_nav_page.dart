import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/models/mangrove_tree.dart';
import '../../home/presentation/pages/scanner_page.dart';
import 'recent_scan_page.dart';
import 'metrics_page.dart';

class MainNavPage extends StatefulWidget {
  const MainNavPage({super.key});

  @override
  State<MainNavPage> createState() => _MainNavPageState();
}

class _MainNavPageState extends State<MainNavPage> {
  static const String _recentScansStorageKey = 'recent_tree_scans_v1';
  static const int _maxRecentScans = 10000;
  static const MethodChannel _downloadsChannel = MethodChannel(
    'mangroveguardapp/downloads',
  );
  static const Color caribbeanGreen = Color(0xFF00DF81);
  static const Color antiFlashWhite = Color(0xFFF1F7F6);
  static const Color bangladeshGreen = Color(0xFF03624C);
  static const Color darkGreen = Color(0xFF032221);

  int _selectedIndex = 0;
  final ScannerPageController _scannerController = ScannerPageController();
  final ValueNotifier<List<RecentTreeScan>> _recentScans = ValueNotifier([]);
  final ValueNotifier<RecentScanNotice?> _recentScanNotice =
      ValueNotifier(null);

  // Pages to switch between
  late final List<Widget> _pages = [
    MetricsPage(scansListenable: _recentScans),
    ScannerPage(
      controller: _scannerController,
      onScanCompleted: _handleScanCompleted,
    ),
    RecentScanPage(
      scansListenable: _recentScans,
      noticeListenable: _recentScanNotice,
      onSaveScan: _saveRecentScan,
      onDeleteScan: _deleteRecentScan,
      onOpenExportPath: _openExportPath,
      onRescan: _handleRescanRequested,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentScans();
  }

  void _setSelectedIndex(int index) {
    if (_selectedIndex == index) return;
    if (_selectedIndex == 1 && index != 1) {
      _scannerController.stopRealtimeAssessment();
    }
    setState(() => _selectedIndex = index);
  }

  void _handleScannerFabTap() {
    if (_selectedIndex == 1) {
      _scannerController.triggerShutter();
      return;
    }
    _setSelectedIndex(1);
  }

  void _handleRescanRequested() {
    if (!mounted) return;
    _setSelectedIndex(1);
  }

void _handleScannerHoldStart() {
    if (!mounted) return;
    if (_selectedIndex != 1) return;  // Ignore long press if not on scanner tab
    if (_scannerController.isRealtimeAssessment) {
      _scannerController.stopRealtimeAssessment();
    } else {
      _scannerController.startRealtimeAssessment();
    }
  }

  void _handleScannerHoldEnd() {
    // Long-press toggles realtime; release does not change state.
  }

  void _handleScanCompleted() {
    unawaited(_storeLatestMeasuredTree());
    if (!mounted) return;
    _setSelectedIndex(2);
  }

  Future<void> _storeLatestMeasuredTree() async {
    final measuredResult = _scannerController.consumeLatestMeasuredTreeResult();
    if (measuredResult == null) return;

    if (measuredResult.outcome == ScanOutcome.noMangroveDetected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _recentScanNotice.value = RecentScanNotice(
          id: DateTime.now().millisecondsSinceEpoch,
          message: 'No mangroves detected. Try a clearer scan.',
          kind: RecentScanNoticeKind.error,
        );
      });
      await _appendActivityLogEntry({
        'event': 'scan_no_mangrove_detected',
        'scannedAt': DateTime.now().toIso8601String(),
      });
      return;
    }

    final timestamp = DateTime.now();
    const treeId = 'Tree #1';
    final capturedImagePath = await _persistCapturedImage(
      sourcePath: measuredResult.capturedImagePath,
      treeId: treeId,
      scannedAt: timestamp,
    );

    final newScan = RecentTreeScan(
      treeId: treeId,
      scannedAt: timestamp,
      tree: measuredResult.tree,
      metersPerPixel: measuredResult.metersPerPixel,
      predictionConfidence: measuredResult.predictionConfidence,
      predictedAssessment: measuredResult.predictedAssessment,
      capturedImagePath: capturedImagePath,
    );

    final updated = [
      newScan,
      ..._recentScans.value,
    ];

    final trimmed = updated.length <= _maxRecentScans
        ? updated
        : updated.sublist(0, _maxRecentScans);
    final removed = updated.length <= _maxRecentScans
        ? const <RecentTreeScan>[]
        : updated.sublist(_maxRecentScans);

    if (!mounted) return;
    _recentScans.value = trimmed;
    await _persistRecentScans(trimmed);
    await _appendActivityLogEntry({
      'event': 'scan_completed',
      'treeId': newScan.treeId,
      'scannedAt': newScan.scannedAt.toIso8601String(),
      'rootCount': newScan.rootCount,
      'stabilityScore': newScan.stabilityScore,
      'assessment': _assessmentLabel(newScan),
      if (newScan.predictionConfidence != null)
        'predictionConfidence': newScan.predictionConfidence,
    });
    for (final scan in removed) {
      await _deleteManagedCaptureFile(scan.capturedImagePath);
    }
  }

  Future<void> _loadRecentScans() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_recentScansStorageKey) ?? const [];
      final loaded = <RecentTreeScan>[];
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) continue;
          loaded.add(RecentTreeScan.fromJson(decoded));
        } catch (_) {
          // Skip malformed entries and continue loading valid scans.
        }
      }
      loaded.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      final limited = loaded.length <= _maxRecentScans
          ? loaded
          : loaded.sublist(0, _maxRecentScans);
      final removed = loaded.length <= _maxRecentScans
          ? const <RecentTreeScan>[]
          : loaded.sublist(_maxRecentScans);
      if (!mounted) return;
      _recentScans.value = limited;
      if (removed.isNotEmpty) {
        await _persistRecentScans(limited);
        for (final scan in removed) {
          await _deleteManagedCaptureFile(scan.capturedImagePath);
        }
      }
    } catch (_) {
      // Ignore storage errors to keep app usable.
    }
  }

  Future<void> _persistRecentScans(List<RecentTreeScan> scans) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = scans
          .map((scan) => jsonEncode(scan.toJson()))
          .toList(growable: false);
      await prefs.setStringList(_recentScansStorageKey, encoded);
    } catch (_) {
      // Ignore persistence failures to avoid interrupting capture flow.
    }
  }

  Future<String?> _saveRecentScan(int index) async {
    if (index < 0 || index >= _recentScans.value.length) return null;
    final scan = _recentScans.value[index];
    final exportPath = await _exportRecentScanPdf(scan);
    await _persistRecentScans(_recentScans.value);
    if (exportPath != null) {
      await _appendActivityLogEntry({
        'event': 'pdf_exported',
        'treeId': scan.treeId,
        'scannedAt': scan.scannedAt.toIso8601String(),
        'exportPath': exportPath,
      });
    }
    return exportPath;
  }

  Future<void> _deleteRecentScan(int index) async {
    if (index < 0 || index >= _recentScans.value.length) return;
    final removedScan = _recentScans.value[index];
    final updated = List<RecentTreeScan>.from(_recentScans.value)
      ..removeAt(index);
    _recentScans.value = updated;
    await _persistRecentScans(updated);
    await _deleteManagedCaptureFile(removedScan.capturedImagePath);
    await _appendActivityLogEntry({
      'event': 'scan_deleted',
      'treeId': removedScan.treeId,
      'scannedAt': removedScan.scannedAt.toIso8601String(),
    });
  }

  Future<bool> _openExportPath(String pdfPath) async {
    try {
      if (!Platform.isAndroid) return false;
      final opened = await _downloadsChannel.invokeMethod<bool>(
        'openExportedPdf',
        {'path': pdfPath},
      );
      return opened ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to open exported PDF path: ${e.code} ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Failed to open exported PDF path: $e');
      return false;
    }
  }

  Future<String?> _persistCapturedImage({
    required String? sourcePath,
    required String treeId,
    required DateTime scannedAt,
  }) async {
    if (sourcePath == null || sourcePath.trim().isEmpty) return null;
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;

      final rootDir = await _resolveStorageRootDirectory();
      final imagesDir = Directory('${rootDir.path}/scan_captures');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final extension = _fileExtension(sourcePath);
      final fileName =
          '${_sanitizeFileName(treeId)}_${scannedAt.millisecondsSinceEpoch}$extension';
      final destination = File('${imagesDir.path}/$fileName');
      await sourceFile.copy(destination.path);
      return destination.path;
    } catch (e) {
      debugPrint('Failed to persist captured scan image: $e');
      return null;
    }
  }

  Future<String?> _exportRecentScanPdf(RecentTreeScan scan) async {
    try {
      final rootDir = await _resolveStorageRootDirectory();
      final exportDir = Directory('${rootDir.path}/scan_exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final capturedImageBytes = await _readCapturedImageBytes(
        scan.capturedImagePath,
      );
      final hasRootOverlayData = scan.tree.roots.any(
        (root) =>
            root.normalizedLeft != null &&
            root.normalizedTop != null &&
            root.normalizedRight != null &&
            root.normalizedBottom != null,
      );
      final highlightedImageBytes = capturedImageBytes == null
          ? null
          : await _buildRootHighlightImage(
              scan: scan,
              sourceBytes: capturedImageBytes,
            );
      final pdf = pw.Document();
      final pdfTheme = await _loadPdfTheme();
      final generatedAt = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          theme: pdfTheme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) {
            final content = <pw.Widget>[
              pw.Text(
                'Mangrove Guard Scan Report',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal900,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Scanned at: ${_formatTimestamp(scan.scannedAt)}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Text(
                'Report generated: ${_formatTimestamp(generatedAt)}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.8,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.2),
                  1: pw.FlexColumnWidth(2.8),
                },
                children: [
                  _buildPdfMetricRow('Detected Roots', '${scan.rootCount}'),
                  _buildPdfMetricRow(
                    'Root Spread',
                    '${scan.rootSpreadCentimeters.toStringAsFixed(1)} cm',
                  ),
                  _buildPdfMetricRow(
                    'Symmetry Score',
                    scan.symmetryScore.toStringAsFixed(2),
                  ),
                  _buildPdfMetricRow(
                    'Stability Score (S)',
                    scan.stabilityScore.toStringAsFixed(2),
                  ),
                  if (scan.predictionConfidence != null)
                    _buildPdfMetricRow(
                      'AI Confidence',
                      '${(scan.predictionConfidence! * 100).toStringAsFixed(0)}%',
                    ),
                  _buildPdfMetricRow('Assessment', _assessmentLabel(scan)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                _assessmentDescription(scan),
                style: const pw.TextStyle(fontSize: 11),
              ),
            ];

            if (highlightedImageBytes != null) {
              final image = pw.MemoryImage(highlightedImageBytes);
              content
                ..add(pw.SizedBox(height: 16))
                ..add(
                  pw.Text(
                    hasRootOverlayData
                        ? 'Captured Image (detected mangrove roots highlighted)'
                        : 'Captured Image',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                )
                ..add(pw.SizedBox(height: 8))
                ..add(
                  pw.Center(
                    child: pw.Container(
                      width: 250,
                      height: 360,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      alignment: pw.Alignment.center,
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ),
                  ),
                );
            } else {
              content
                ..add(pw.SizedBox(height: 16))
                ..add(
                  pw.Text(
                    'Captured image unavailable for this scan.',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  ),
                );
            }

            return content;
          },
        ),
      );

      final fileName = 'scan_${scan.scannedAt.millisecondsSinceEpoch}.pdf';

      final pdfBytes = await pdf.save();
      if (Platform.isAndroid) {
        final downloadRef = await _savePdfToAndroidDownloads(
          bytes: pdfBytes,
          fileName: fileName,
        );
        if (downloadRef != null) return downloadRef;
      }

      final file = File('${exportDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('Failed to export scan PDF: $e');
      return null;
    }
  }

  Future<String?> _savePdfToAndroidDownloads({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final savedRef = await _downloadsChannel.invokeMethod<String>(
        'savePdfToDownloads',
        {'bytes': bytes, 'fileName': fileName},
      );
      return savedRef;
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to save PDF to Android Downloads: ${e.code} ${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('Failed to save PDF to Android Downloads: $e');
      return null;
    }
  }

  Future<pw.ThemeData> _loadPdfTheme() async {
    try {
      final regular = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
      final bold = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
      return pw.ThemeData.withFont(
        base: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
      );
    } catch (e) {
      debugPrint('Failed to load PDF Unicode fonts, using defaults: $e');
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  Future<Uint8List?> _buildRootHighlightImage({
    required RecentTreeScan scan,
    required Uint8List sourceBytes,
  }) async {
    try {
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return sourceBytes;

      final width = decoded.width > 1800 ? 1800 : decoded.width;
      final working = decoded.width > width
          ? img.copyResize(decoded, width: width)
          : img.Image.from(decoded);
      final roots = scan.tree.roots;
      if (roots.isEmpty) return Uint8List.fromList(img.encodeJpg(working));

      final rootColor = img.ColorRgb8(0, 223, 129);
      final hasNormalizedBoxes = roots.any(
        (root) =>
            root.normalizedLeft != null &&
            root.normalizedTop != null &&
            root.normalizedRight != null &&
            root.normalizedBottom != null,
      );

      if (!hasNormalizedBoxes) {
        // Legacy scans without normalized detection bounds are left unmodified.
        return sourceBytes;
      }

      for (final root in roots) {
        final left = root.normalizedLeft;
        final top = root.normalizedTop;
        final right = root.normalizedRight;
        final bottom = root.normalizedBottom;
        if (left == null || top == null || right == null || bottom == null) {
          continue;
        }

        final x1 = (left.clamp(0.0, 1.0) * (working.width - 1)).round();
        final y1 = (top.clamp(0.0, 1.0) * (working.height - 1)).round();
        final x2 = (right.clamp(0.0, 1.0) * (working.width - 1)).round();
        final y2 = (bottom.clamp(0.0, 1.0) * (working.height - 1)).round();

        img.drawRect(
          working,
          x1: x1,
          y1: y1,
          x2: x2,
          y2: y2,
          color: rootColor,
          thickness: 3,
        );
        img.fillCircle(
          working,
          x: ((x1 + x2) / 2).round(),
          y: ((y1 + y2) / 2).round(),
          radius: 3,
          color: rootColor,
        );
      }

      return Uint8List.fromList(img.encodeJpg(working, quality: 92));
    } catch (e) {
      debugPrint('Failed to render root highlight image: $e');
      return sourceBytes;
    }
  }

  Future<Directory> _resolveStorageRootDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } on MissingPluginException catch (e) {
      debugPrint('Path provider plugin unavailable, using temp storage: $e');
    } on PlatformException catch (e) {
      debugPrint(
        'Path provider channel error, using temp storage: ${e.code} ${e.message}',
      );
    } catch (e) {
      debugPrint('Unable to resolve app documents directory: $e');
    }

    final fallback = Directory('${Directory.systemTemp.path}/mangroveguardapp');
    if (!await fallback.exists()) {
      await fallback.create(recursive: true);
    }
    return fallback;
  }

  Future<void> _appendActivityLogEntry(Map<String, dynamic> entry) async {
    try {
      final rootDir = await _resolveStorageRootDirectory();
      final logsDir = Directory('${rootDir.path}/scan_logs');
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final enriched = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        ...entry,
      };
      final file = File('${logsDir.path}/activity_log.jsonl');
      await file.writeAsString(
        '${jsonEncode(enriched)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Ignore logging failures to keep capture/report flows reliable.
    }
  }

  Future<Uint8List?> _readCapturedImageBytes(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return null;
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteManagedCaptureFile(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return;
    if (!filePath.contains('scan_captures')) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore file delete failures to avoid blocking UI actions.
    }
  }

  pw.TableRow _buildPdfMetricRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  String _assessmentLabel(RecentTreeScan scan) {
    return scan.assessment.label;
  }

  String _assessmentDescription(RecentTreeScan scan) {
    return scan.assessment.description;
  }

  String _formatTimestamp(DateTime value) {
    final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${_monthName(value.month)} ${value.day}, ${value.year} $hour12:$minute $period';
  }

  String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }

  String _sanitizeFileName(String value) {
    final sanitized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return sanitized.isEmpty ? 'scan' : sanitized;
  }

  String _fileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1) return '.jpg';
    final extension = path.substring(dotIndex).toLowerCase();
    if (extension.length > 8 || extension.contains('/')) return '.jpg';
    return extension;
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _recentScans.dispose();
    _recentScanNotice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      // IndexedStack prevents the AR camera from "restarting" every time you switch tabs
      body: IndexedStack(index: _selectedIndex, children: _pages),
      // Glassmorphic Floating Dock Navigation Bar
      bottomNavigationBar: SizedBox(
        height: 112,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    height: 85,
                    decoration: BoxDecoration(
                      color: darkGreen.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(
                        color: bangladeshGreen.withValues(alpha: 0.85),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavItem(
                          icon: Icons.dashboard_rounded,
                          isSelected: _selectedIndex == 0,
                          selectedColor: caribbeanGreen,
                          unselectedColor: antiFlashWhite.withValues(
                            alpha: 0.58,
                          ),
                          onTap: () => _setSelectedIndex(0),
                        ),
                        const SizedBox(width: 70),
                        _NavItem(
                          icon: Icons.auto_stories_rounded,
                          isSelected: _selectedIndex == 2,
                          selectedColor: caribbeanGreen,
                          unselectedColor: antiFlashWhite.withValues(
                            alpha: 0.58,
                          ),
                          onTap: () => _setSelectedIndex(2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
Positioned(
              top: 0,
              child: AnimatedBuilder(
                animation: _scannerController,
                builder: (context, child) {
                  return _ScannerFab(
                    isScannerActive: _selectedIndex == 1,
                    showLiveAnimation: _scannerController.isRealtimeAssessment,
                    selectedColor: caribbeanGreen,
                    baseColor: bangladeshGreen,
                    iconColor: antiFlashWhite,
                    onTap: _handleScannerFabTap,
                    onHoldStart: _handleScannerHoldStart,
                    onHoldEnd: _handleScannerHoldEnd,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerFab extends StatefulWidget {
  final bool isScannerActive;
  final Color selectedColor;
  final Color baseColor;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback? onHoldStart;
final VoidCallback? onHoldEnd;
  final bool showLiveAnimation;

const _ScannerFab({
    required this.isScannerActive,
    required this.showLiveAnimation,
    required this.selectedColor,
    required this.baseColor,
    required this.iconColor,
    required this.onTap,
    this.onHoldStart,
    this.onHoldEnd,
  });

  @override
  State<_ScannerFab> createState() => _ScannerFabState();
}

class _ScannerFabState extends State<_ScannerFab> {
  Timer? _pressTimer;
  bool _isShutterPressed = false;
  bool _isLongPressing = false;

  void _handleTap() {
    if (_isLongPressing) return;
    widget.onTap();
  }

  void _handleTapDown(TapDownDetails details) {
    _pressTimer?.cancel();
    if (mounted) {
      setState(() => _isShutterPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isLongPressing) return;
    _pressTimer?.cancel();
    _pressTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() => _isShutterPressed = false);
    });
  }

  void _handleTapCancel() {
    if (_isLongPressing) return;
    _pressTimer?.cancel();
    if (mounted) {
      setState(() => _isShutterPressed = false);
    }
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _pressTimer?.cancel();
    _isLongPressing = true;
    if (mounted) {
      setState(() => _isShutterPressed = true);
    }
    widget.onHoldStart?.call();
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    _pressTimer?.cancel();
    _isLongPressing = false;
    if (mounted) {
      setState(() => _isShutterPressed = false);
    }
    widget.onHoldEnd?.call();
  }

  @override
  void didUpdateWidget(covariant _ScannerFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isScannerActive && _isShutterPressed) {
      _pressTimer?.cancel();
      _isShutterPressed = false;
      _isLongPressing = false;
    }
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.isScannerActive
          ? 'Capture shutter, hold to toggle live assessment'
          : 'Open scanner',
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: _handleTap,
        onLongPressStart: _handleLongPressStart,
        onLongPressEnd: _handleLongPressEnd,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          scale: _isShutterPressed ? 0.9 : 1.0,
          child: SizedBox(
            width: 106,
            height: 106,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: widget.isScannerActive ? 100 : 84,
                  height: widget.isScannerActive ? 100 : 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.selectedColor.withValues(
                          alpha: widget.isScannerActive ? 0.34 : 0.14,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: widget.isScannerActive ? 88 : 74,
                  height: widget.isScannerActive ? 88 : 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isScannerActive
                          ? [const Color(0xFF0A7D64), widget.selectedColor]
                          : [const Color(0xFF054D3D), widget.baseColor],
                    ),
                    border: Border.all(
                      color: widget.iconColor.withValues(
                        alpha: widget.isScannerActive ? 0.68 : 0.24,
                      ),
                      width: widget.isScannerActive ? 2.0 : 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.selectedColor.withValues(
                          alpha: widget.isScannerActive ? 0.32 : 0.14,
                        ),
                        blurRadius: widget.isScannerActive ? 24 : 12,
                        spreadRadius: widget.isScannerActive ? 1.6 : 0,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: widget.isScannerActive ? 62 : 56,
                        height: widget.isScannerActive ? 62 : 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.26),
                              Colors.black.withValues(alpha: 0.1),
                            ],
                          ),
                          border: Border.all(
                            color: widget.iconColor.withValues(
                              alpha: widget.isScannerActive ? 0.28 : 0.18,
                            ),
                            width: 1.0,
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                        opacity: _isShutterPressed ? 0.16 : 0.0,
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.iconColor,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: animation,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            ),
                        child: widget.isScannerActive
                            ? _ShutterVisual(iconColor: widget.iconColor)
                            : _ScannerVisual(iconColor: widget.iconColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShutterVisual extends StatefulWidget {
  final Color iconColor;

  const _ShutterVisual({required this.iconColor});

@override
  State<_ShutterVisual> createState() => _ShutterVisualState();
}

class _ShutterVisualState extends State<_ShutterVisual>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _ringScale1;
  late Animation<double> _ringAlpha1;
  late Animation<double> _ringScale2;
  late Animation<double> _ringAlpha2;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    // Radar ring 1
    _ringScale1 = Tween<double>(begin: 0.6, end: 1.6).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );
    _ringAlpha1 = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

// Radar ring 2 (delayed)
    _ringScale2 = Tween<double>(begin: 0.6, end: 1.6).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _ringAlpha2 = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final parentFab = context.findAncestorWidgetOfExactType<_ScannerFab>();
        final isLive = parentFab?.showLiveAnimation ?? false;
        return SizedBox(
          key: const ValueKey('shutter'),
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Radar pulse rings (live only)
              if (isLive) ...[
                // Outer ring
                Positioned.fill(
                  child: Transform.scale(
                    scale: _ringScale2.value,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00DF81).withValues(
                            alpha: _ringAlpha2.value,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // Inner ring
                Positioned.fill(
                  child: Transform.scale(
                    scale: _ringScale1.value,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00DF81).withValues(
                            alpha: _ringAlpha1.value * 0.7,
                          ),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              // Core button with subtle pulse
              AnimatedScale(
                scale: isLive ? _scaleAnimation.value : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.22),
                    border: Border.all(
                      color: widget.iconColor.withValues(alpha: 0.82),
                      width: 1.8,
                    ),
                    boxShadow: isLive
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00DF81).withValues(
                                alpha: _glowAnimation.value * 0.6,
                              ),
                              blurRadius: 12 + (_glowAnimation.value * 12),
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              // Center shutter circle
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F7F6),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerVisual extends StatelessWidget {
  final Color iconColor;

  const _ScannerVisual({required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('scanner'),
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.2),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.34),
                width: 1.1,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.crop_free_rounded,
                  color: iconColor.withValues(alpha: 0.9),
                  size: 30,
                ),
                Icon(
                  Icons.add_rounded,
                  color: iconColor.withValues(alpha: 0.9),
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Navigation Item Widget
class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 26,
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
