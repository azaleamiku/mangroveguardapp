import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../home/models/mangrove_tree.dart';

const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

String _stabilityLabel(StabilityAssessment assessment) {
  return assessment.label;
}

class RecentScanPage extends StatefulWidget {
  final ValueListenable<List<RecentTreeScan>> scansListenable;
  final Future<String?> Function(int index)? onSaveScan;
  final Future<void> Function(int index)? onDeleteScan;
  final Future<bool> Function(String pdfPath)? onOpenExportPath;
  final VoidCallback? onRescan;

  const RecentScanPage({
    super.key,
    required this.scansListenable,
    this.onSaveScan,
    this.onDeleteScan,
    this.onOpenExportPath,
    this.onRescan,
  });

  @override
  State<RecentScanPage> createState() => _RecentScanPageState();
}

class _RecentScanPageState extends State<RecentScanPage> {
  int? _expandedIndex;
  Timer? _noticeTimer;
  _RecentScanNotice? _notice;
  bool _showNoticeCard = false;
  bool _detailsExpanded = false;
  bool _peekRawPhoto = false;
  final Map<String, Size> _imageSizeCache = {};
  final Map<String, ui.Image> _rootMaskImageCache = {};
  final Map<String, Future<ui.Image?>> _rootMaskImageFutureCache = {};
  final Map<String, ui.Image> _trunkMaskImageCache = {};
  final Map<String, Future<ui.Image?>> _trunkMaskImageFutureCache = {};

  Future<void> _handleSaveScan(int index) async {
    final saveCallback = widget.onSaveScan;
    if (saveCallback == null) return;

    final exportedPdfPath = await saveCallback(index);
    if (!mounted) return;
    final filename = exportedPdfPath?.split('/').last;
    _showNotice(
      message: filename == null
          ? 'PDF export failed. Try a full app restart.'
          : 'PDF exported to Downloads/MangroveGuard: $filename',
      kind: filename == null ? _NoticeKind.error : _NoticeKind.success,
      actionPath: exportedPdfPath,
    );
  }

  Future<void> _handleDeleteScan(int index, String treeId) async {
    final deleteCallback = widget.onDeleteScan;
    if (deleteCallback == null) return;

    await deleteCallback(index);
    if (!mounted) return;
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    _showNotice(message: '$treeId deleted.', kind: _NoticeKind.delete);
  }

  void _handleRescan() {
    final callback = widget.onRescan;
    if (callback == null) return;
    callback();
  }

  Future<Size?> _loadImageSize(String path) async {
    final cached = _imageSizeCache[path];
    if (cached != null) return cached;
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = await _decodeImage(bytes);
      final size = Size(decoded.width.toDouble(), decoded.height.toDouble());
      decoded.dispose();
      _imageSizeCache[path] = size;
      return size;
    } catch (_) {
      return null;
    }
  }

  String _maskCacheKey(RecentTreeScan scan) {
    final stamp = scan.scannedAt.millisecondsSinceEpoch;
    final path = scan.capturedImagePath ?? '';
    return '${scan.treeId}::$stamp::$path';
  }

  Future<ui.Image?> _loadRootMaskImage(RecentTreeScan scan) {
    final bytes = scan.rootMaskBytes;
    final width = scan.rootMaskWidth;
    final height = scan.rootMaskHeight;
    if (bytes == null || width == null || height == null) {
      return Future.value(null);
    }
    if (width <= 0 || height <= 0) {
      return Future.value(null);
    }
    final key = _maskCacheKey(scan);
    final cached = _rootMaskImageCache[key];
    if (cached != null) return Future.value(cached);
    final existing = _rootMaskImageFutureCache[key];
    if (existing != null) return existing;

    final future = _decodeRootMaskImage(bytes, width, height).then((image) {
      if (image != null) {
        _rootMaskImageCache[key] = image;
      }
      return image;
    });
    _rootMaskImageFutureCache[key] = future;
    return future;
  }

  Future<ui.Image?> _loadTrunkMaskImage(RecentTreeScan scan) {
    final bytes = scan.trunkMaskBytes;
    final width = scan.trunkMaskWidth;
    final height = scan.trunkMaskHeight;
    if (bytes == null || width == null || height == null) {
      return Future.value(null);
    }
    if (width <= 0 || height <= 0) {
      return Future.value(null);
    }
    final key = _maskCacheKey(scan);
    final cached = _trunkMaskImageCache[key];
    if (cached != null) return Future.value(cached);
    final existing = _trunkMaskImageFutureCache[key];
    if (existing != null) return existing;

    final future = _decodePackedMaskImage(
      bytes,
      width,
      height,
      color: const Color(0xFFFFA34D),
      alphaFraction: 0.42,
    ).then((image) {
      if (image != null) {
        _trunkMaskImageCache[key] = image;
      }
      return image;
    });
    _trunkMaskImageFutureCache[key] = future;
    return future;
  }

  Future<ui.Image?> _decodeRootMaskImage(
    Uint8List bytes,
    int width,
    int height,
  ) {
    return _decodePackedMaskImage(
      bytes,
      width,
      height,
      color: caribbeanGreen,
      alphaFraction: 0.55,
    );
  }

  Future<ui.Image?> _decodePackedMaskImage(
    Uint8List bytes,
    int width,
    int height, {
    required Color color,
    required double alphaFraction,
  }) {
    try {
      final pixelCount = width * height;
      if (pixelCount <= 0) return Future.value(null);
      final rgba = Uint8List(pixelCount * 4);
      final alpha = (alphaFraction.clamp(0.0, 1.0) * 255).round();
      final totalBits = math.min(pixelCount, bytes.length * 8);
      var rgbaIndex = 0;

      for (var i = 0; i < totalBits; i++) {
        final byte = bytes[i >> 3];
        final bit = 7 - (i & 7);
        if ((byte & (1 << bit)) != 0) {
          rgba[rgbaIndex] = color.red;
          rgba[rgbaIndex + 1] = color.green;
          rgba[rgbaIndex + 2] = color.blue;
          rgba[rgbaIndex + 3] = alpha;
        } else {
          rgba[rgbaIndex + 3] = 0;
        }
        rgbaIndex += 4;
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, (
        image,
      ) {
        if (!completer.isCompleted) {
          completer.complete(image);
        }
      });
      return completer.future;
    } catch (_) {
      return Future.value(null);
    }
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (image) {
      if (!completer.isCompleted) {
        completer.complete(image);
      }
    });
    return completer.future;
  }

  Future<void> _handleClearScans(int count) async {
    final deleteCallback = widget.onDeleteScan;
    if (deleteCallback == null || count == 0) return;

    for (var index = count - 1; index >= 0; index--) {
      await deleteCallback(index);
      if (!mounted) return;
    }

    if (!mounted) return;
    setState(() => _expandedIndex = null);
    _showNotice(message: 'Recent scans cleared.', kind: _NoticeKind.delete);
  }

  List<Rect> _normalizedRootRects(MangroveTree tree) {
    final rects = <Rect>[];
    for (final root in tree.roots) {
      final left = root.normalizedLeft;
      final top = root.normalizedTop;
      final right = root.normalizedRight;
      final bottom = root.normalizedBottom;
      if (left == null || top == null || right == null || bottom == null) {
        continue;
      }
      final clampedLeft = left.clamp(0.0, 1.0);
      final clampedTop = top.clamp(0.0, 1.0);
      final clampedRight = right.clamp(0.0, 1.0);
      final clampedBottom = bottom.clamp(0.0, 1.0);
      rects.add(
        Rect.fromLTRB(
          math.min(clampedLeft, clampedRight),
          math.min(clampedTop, clampedBottom),
          math.max(clampedLeft, clampedRight),
          math.max(clampedTop, clampedBottom),
        ),
      );
    }
    return rects;
  }

  List<Rect> _normalizedTrunkRects(MangroveTree tree) {
    final bounds = tree.treeBounds;
    if (bounds == null) return const [];
    final clampedLeft = bounds.left.clamp(0.0, 1.0);
    final clampedTop = bounds.top.clamp(0.0, 1.0);
    final clampedRight = bounds.right.clamp(0.0, 1.0);
    final clampedBottom = bounds.bottom.clamp(0.0, 1.0);
    return [
      Rect.fromLTRB(
        math.min(clampedLeft, clampedRight),
        math.min(clampedTop, clampedBottom),
        math.max(clampedLeft, clampedRight),
        math.max(clampedTop, clampedBottom),
      ),
    ];
  }

  void _showNotice({
    required String message,
    required _NoticeKind kind,
    String? actionPath,
  }) {
    _noticeTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _notice = _RecentScanNotice(
        message: message,
        kind: kind,
        actionPath: actionPath,
      );
      _showNoticeCard = true;
    });

    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showNoticeCard = false);
    });
  }

  void _dismissNotice() {
    _noticeTimer?.cancel();
    if (!mounted) return;
    setState(() => _showNoticeCard = false);
  }

  Future<void> _handleNoticeTap() async {
    final notice = _notice;
    final openExportPath = widget.onOpenExportPath;
    if (notice == null || notice.actionPath == null || openExportPath == null) {
      return;
    }

    final opened = await openExportPath(notice.actionPath!);
    if (!mounted || opened) return;

    _showNotice(
      message: 'Unable to open Files app for this export.',
      kind: _NoticeKind.error,
    );
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    for (final image in _rootMaskImageCache.values) {
      image.dispose();
    }
    for (final image in _trunkMaskImageCache.values) {
      image.dispose();
    }
    super.dispose();
  }

  String _formatTimestamp(DateTime value) {
    final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    final month = _monthName(value.month);
    return '$month ${value.day}, ${value.year} • $hour12:$minute $period';
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

  Color _assessmentColor(StabilityAssessment assessment) {
    switch (assessment) {
      case StabilityAssessment.high:
        return caribbeanGreen;
      case StabilityAssessment.moderate:
        return const Color(0xFFF59E0B);
      case StabilityAssessment.low:
        return const Color(0xFFEF4444);
      case StabilityAssessment.veryUnstable:
        return const Color(0xFFB91C1C);
    }
  }

  double _scannerFrameAspect(Size size) {
    final frameWidth = (size.width * 0.82).clamp(280.0, 340.0);
    final frameHeight = (size.height * 0.5).clamp(320.0, 420.0);
    final innerWidth = (frameWidth - 30).clamp(250.0, 305.0);
    final innerHeight = (frameHeight - 28).clamp(290.0, 385.0);
    return innerWidth / innerHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: richBlack,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ValueListenableBuilder<List<RecentTreeScan>>(
          valueListenable: widget.scansListenable,
          builder: (context, scans, child) {
            if (scans.isEmpty) {
              final size = MediaQuery.sizeOf(context);
              final topInset = MediaQuery.paddingOf(context).top;
              final bottomInset = MediaQuery.paddingOf(context).bottom;
              const bottomNavHeight = 112.0;
              final availableHeight =
                  size.height - topInset - bottomInset - bottomNavHeight;
              final topOffset = topInset + (availableHeight * 0.32);

              return Padding(
                padding: EdgeInsets.fromLTRB(16, topOffset, 16, 0),
                child: const _EmptyRecentScanCard(),
              );
            }

            final scan = scans.first;
            final imagePath = scan.capturedImagePath?.trim();
            final hasImage = imagePath != null && imagePath.isNotEmpty;
            final statusColor = _assessmentColor(scan.assessment);
            final stabilityRatio = scan.stabilityScore.clamp(0.0, 1.0);
            final photoBorderWidth = 1.4 + (stabilityRatio * 1.8);
            final photoBorderColor = statusColor.withValues(alpha: 0.75);
            final topInset = MediaQuery.paddingOf(context).top;
            const extraTopPadding = 30.0;
            final contentTopPadding = topInset + extraTopPadding;
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            const bottomNavHeight = 112.0;
            const extraBottomPadding = 12.0;
            final contentBottomPadding =
                bottomInset + bottomNavHeight + extraBottomPadding;
            final frameAspect = _scannerFrameAspect(MediaQuery.sizeOf(context));
            final rootRects = _normalizedRootRects(scan.tree);
            final trunkRects = _normalizedTrunkRects(scan.tree);
            final hasRootMask =
                scan.rootMaskBytes != null &&
                (scan.rootMaskWidth ?? 0) > 0 &&
                (scan.rootMaskHeight ?? 0) > 0;
            final hasTrunkMask =
                scan.trunkMaskBytes != null &&
                (scan.trunkMaskWidth ?? 0) > 0 &&
                (scan.trunkMaskHeight ?? 0) > 0;
            final hasAnyHighlight =
                hasRootMask ||
                hasTrunkMask ||
                rootRects.isNotEmpty ||
                trunkRects.isNotEmpty;
            final showHighlights = !_peekRawPhoto;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                contentTopPadding + 8,
                16,
                contentBottomPadding,
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: frameAspect,
                    child: Stack(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: photoBorderColor,
                              width: photoBorderWidth,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(photoBorderWidth),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: hasImage
                                  ? FutureBuilder<Size?>(
                                      future: _loadImageSize(imagePath),
                                      builder: (context, snapshot) {
                                    final imageSize = snapshot.data;
                                    if (imageSize == null) {
                                      return Image.file(
                                        File(imagePath),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Container(
                                                color: darkGreen.withValues(
                                                  alpha: 0.55,
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.broken_image_rounded,
                                                    color: antiFlashWhite,
                                                    size: 36,
                                                  ),
                                                ),
                                              );
                                            },
                                      );
                                    }

                                    return FittedBox(
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        width: imageSize.width,
                                        height: imageSize.height,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.file(
                                              File(imagePath),
                                              fit: BoxFit.fill,
                                              width: imageSize.width,
                                              height: imageSize.height,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      color: darkGreen
                                                          .withValues(
                                                            alpha: 0.55,
                                                          ),
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons
                                                              .broken_image_rounded,
                                                          color: antiFlashWhite,
                                                          size: 36,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                            ),
                                            if (showHighlights && hasTrunkMask)
                                              FutureBuilder<ui.Image?>(
                                                future: _loadTrunkMaskImage(
                                                  scan,
                                                ),
                                                builder: (context, snapshot) {
                                                  final maskImage =
                                                      snapshot.data;
                                                  if (maskImage == null) {
                                                    if (trunkRects.isNotEmpty) {
                                                      return CustomPaint(
                                                        painter:
                                                            _RootHighlightPainter(
                                                              rects: trunkRects,
                                                              color: const Color(
                                                                0xFFFFA34D,
                                                              ),
                                                            ),
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  }
                                                  return CustomPaint(
                                                    painter: _RootMaskPainter(
                                                      maskImage: maskImage,
                                                      maskSize: Size(
                                                        scan.trunkMaskWidth!
                                                            .toDouble(),
                                                        scan.trunkMaskHeight!
                                                            .toDouble(),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            else if (showHighlights &&
                                                trunkRects.isNotEmpty)
                                              CustomPaint(
                                                painter: _RootHighlightPainter(
                                                  rects: trunkRects,
                                                  color: const Color(
                                                    0xFFFFA34D,
                                                  ),
                                                ),
                                              ),
                                            if (showHighlights && hasRootMask)
                                              FutureBuilder<ui.Image?>(
                                                future: _loadRootMaskImage(
                                                  scan,
                                                ),
                                                builder: (context, snapshot) {
                                                  final maskImage =
                                                      snapshot.data;
                                                  if (maskImage == null) {
                                                    if (rootRects.isNotEmpty) {
                                                      return CustomPaint(
                                                        painter:
                                                            _RootHighlightPainter(
                                                              rects: rootRects,
                                                              color:
                                                                  caribbeanGreen,
                                                            ),
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  }
                                                  return CustomPaint(
                                                    painter: _RootMaskPainter(
                                                      maskImage: maskImage,
                                                      maskSize: Size(
                                                        scan.rootMaskWidth!
                                                            .toDouble(),
                                                        scan.rootMaskHeight!
                                                            .toDouble(),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            else if (showHighlights &&
                                                rootRects.isNotEmpty)
                                              CustomPaint(
                                                painter: _RootHighlightPainter(
                                                  rects: rootRects,
                                                  color: caribbeanGreen,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: darkGreen.withValues(alpha: 0.55),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_rounded,
                                      color: antiFlashWhite,
                                      size: 36,
                                    ),
                                  ),
                                ),
                            ),
                          ),
                        ),
                        if (hasImage && hasAnyHighlight)
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: _PeekHighlightButton(
                              pressed: _peekRawPhoto,
                              onPressedChanged: (pressed) {
                                if (!mounted) return;
                                setState(() => _peekRawPhoto = pressed);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [darkGreen.withValues(alpha: 0.95), richBlack],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.55),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mangrove Stability',
                              style: TextStyle(
                                color: antiFlashWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Text(
                                _stabilityLabel(scan.assessment),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: antiFlashWhite.withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTimestamp(scan.scannedAt),
                              style: TextStyle(
                                color: antiFlashWhite.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          color: bangladeshGreen.withValues(alpha: 0.5),
                          height: 1,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Highlights',
                              style: TextStyle(
                                color: antiFlashWhite.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      bangladeshGreen.withValues(alpha: 0.6),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final tileWidth = (constraints.maxWidth - 12) / 2;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: tileWidth,
                                  child: _MetricTile(
                                    label: 'Root Count',
                                    value: '${scan.rootCount}',
                                    icon: Icons.nature_rounded,
                                    accent: statusColor,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _MetricTile(
                                    label: 'Root Spread',
                                    value:
                                        '${scan.rootSpreadCentimeters.toStringAsFixed(1)} cm',
                                    icon: Icons.open_in_full_rounded,
                                    accent: statusColor,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _MetricTile(
                                    label: 'Stability Score',
                                    value: scan.stabilityScore.toStringAsFixed(
                                      2,
                                    ),
                                    icon: Icons.speed_rounded,
                                    accent: statusColor,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _MetricTile(
                                    label: 'Symmetry Score',
                                    value: scan.symmetryScore.toStringAsFixed(
                                      2,
                                    ),
                                    icon: Icons.balance_rounded,
                                    accent: statusColor,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _MetricTile(
                                    label: 'Stability Level',
                                    value: scan.assessment.label,
                                    icon: Icons.verified_rounded,
                                    accent: statusColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF064E3B),
                                      Color(0xFF10B981),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF86EFAC,
                                    ).withValues(alpha: 0.34),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.24),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: FilledButton(
                                    onPressed: () => _handleSaveScan(0),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: antiFlashWhite,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Icon(
                                          Icons.picture_as_pdf_rounded,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Export'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0F766E),
                                      Color(0xFF14B8A6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF5EEAD4,
                                    ).withValues(alpha: 0.32),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF14B8A6,
                                      ).withValues(alpha: 0.22),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: FilledButton(
                                    onPressed: _handleRescan,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: antiFlashWhite,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Icon(
                                          Icons.center_focus_strong_rounded,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Rescan'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRect(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: _detailsExpanded
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.18,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          'Stability Score (0–1): ${scan.stabilityScore.toStringAsFixed(2)}'
                                          ' • Symmetry: ${scan.symmetryScore.toStringAsFixed(2)}'
                                          ' • Coverage: ${scan.rootCoverageRatio.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: antiFlashWhite.withValues(
                                              alpha: 0.86,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 7,
                                        runSpacing: 7,
                                        children: [
                                          _ThresholdChip(
                                            label: 'High (0.75–1.00)',
                                            active:
                                                scan.assessment ==
                                                StabilityAssessment.high,
                                            color: caribbeanGreen,
                                          ),
                                          _ThresholdChip(
                                            label: 'Moderate (0.50–0.74)',
                                            active:
                                                scan.assessment ==
                                                StabilityAssessment.moderate,
                                            color: const Color(0xFFF59E0B),
                                          ),
                                          _ThresholdChip(
                                            label: 'Low (0.25–0.49)',
                                            active:
                                                scan.assessment ==
                                                StabilityAssessment.low,
                                            color: const Color(0xFFEF4444),
                                          ),
                                          _ThresholdChip(
                                            label: 'Very Unstable (0.00–0.24)',
                                            active:
                                                scan.assessment ==
                                                StabilityAssessment
                                                    .veryUnstable,
                                            color: const Color(0xFFB91C1C),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        scan.assessment.description,
                                        style: TextStyle(
                                          color: antiFlashWhite.withValues(
                                            alpha: 0.76,
                                          ),
                                          fontSize: 11,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _detailsExpanded = !_detailsExpanded,
                            ),
                            icon: Icon(
                              _detailsExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: antiFlashWhite.withValues(alpha: 0.8),
                              size: 18,
                            ),
                            label: Text(
                              _detailsExpanded
                                  ? 'Hide details'
                                  : 'Show more details',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: antiFlashWhite.withValues(
                                alpha: 0.84,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RootHighlightPainter extends CustomPainter {
  final List<Rect> rects;
  final Color color;

  const _RootHighlightPainter({required this.rects, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (rects.isEmpty) return;

    final stroke = math.max(1.4, size.shortestSide * 0.0035);
    final glowBlur = stroke * 3.2;
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.12);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 2.1
      ..color = color.withValues(alpha: 0.32)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, glowBlur);

    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.92);

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 1.15
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.85);

    for (final rect in rects) {
      final scaled = Rect.fromLTRB(
        rect.left * size.width,
        rect.top * size.height,
        rect.right * size.width,
        rect.bottom * size.height,
      );

      final radius = math.max(6.0, stroke * 2.6);
      final rrect = RRect.fromRectAndRadius(scaled, Radius.circular(radius));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, glowPaint);
      canvas.drawRRect(rrect, outlinePaint);

      final maxTick = math.min(scaled.width, scaled.height) * 0.28;
      final tick = math.max(8.0, math.min(16.0, maxTick));
      final left = scaled.left;
      final top = scaled.top;
      final right = scaled.right;
      final bottom = scaled.bottom;

      canvas.drawLine(
        Offset(left + radius * 0.6, top),
        Offset(left + radius * 0.6 + tick, top),
        tickPaint,
      );
      canvas.drawLine(
        Offset(left, top + radius * 0.6),
        Offset(left, top + radius * 0.6 + tick),
        tickPaint,
      );

      canvas.drawLine(
        Offset(right - radius * 0.6 - tick, top),
        Offset(right - radius * 0.6, top),
        tickPaint,
      );
      canvas.drawLine(
        Offset(right, top + radius * 0.6),
        Offset(right, top + radius * 0.6 + tick),
        tickPaint,
      );

      canvas.drawLine(
        Offset(left + radius * 0.6, bottom),
        Offset(left + radius * 0.6 + tick, bottom),
        tickPaint,
      );
      canvas.drawLine(
        Offset(left, bottom - radius * 0.6 - tick),
        Offset(left, bottom - radius * 0.6),
        tickPaint,
      );

      canvas.drawLine(
        Offset(right - radius * 0.6 - tick, bottom),
        Offset(right - radius * 0.6, bottom),
        tickPaint,
      );
      canvas.drawLine(
        Offset(right, bottom - radius * 0.6 - tick),
        Offset(right, bottom - radius * 0.6),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RootHighlightPainter oldDelegate) {
    return oldDelegate.color != color || !listEquals(oldDelegate.rects, rects);
  }
}

class _RootMaskPainter extends CustomPainter {
  final ui.Image maskImage;
  final Size maskSize;

  const _RootMaskPainter({required this.maskImage, required this.maskSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (maskSize.width <= 0 || maskSize.height <= 0) return;
    final src = Rect.fromLTWH(0, 0, maskSize.width, maskSize.height);
    final dst = Offset.zero & size;
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..blendMode = BlendMode.srcOver;
    canvas.drawImageRect(maskImage, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _RootMaskPainter oldDelegate) {
    return oldDelegate.maskImage != maskImage ||
        oldDelegate.maskSize != maskSize;
  }
}

class _PeekHighlightButton extends StatelessWidget {
  final bool pressed;
  final ValueChanged<bool> onPressedChanged;

  const _PeekHighlightButton({
    required this.pressed,
    required this.onPressedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = pressed ? antiFlashWhite : caribbeanGreen;
    return Semantics(
      label: 'Hide highlights',
      button: true,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: pressed ? 0.97 : 1.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                darkGreen.withValues(alpha: 0.84),
                richBlack.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: pressed ? 0.22 : 0.16),
                blurRadius: 14,
                spreadRadius: 0.4,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onHighlightChanged: onPressedChanged,
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Icon(
                  pressed
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18,
                  color: antiFlashWhite.withValues(
                    alpha: pressed ? 0.96 : 0.86,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _NoticeKind { success, delete, error }

class _RecentScanNotice {
  final String message;
  final _NoticeKind kind;
  final String? actionPath;

  const _RecentScanNotice({
    required this.message,
    required this.kind,
    this.actionPath,
  });
}

class _RecentScanNoticeCard extends StatelessWidget {
  final _RecentScanNotice notice;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const _RecentScanNoticeCard({
    required this.notice,
    required this.onClose,
    required this.onTap,
  });

  Color _accentColor() {
    switch (notice.kind) {
      case _NoticeKind.success:
        return const Color(0xFF10B981);
      case _NoticeKind.delete:
        return const Color(0xFFEF4444);
      case _NoticeKind.error:
        return const Color(0xFFF97316);
    }
  }

  IconData _icon() {
    switch (notice.kind) {
      case _NoticeKind.success:
        return Icons.task_alt_rounded;
      case _NoticeKind.delete:
        return Icons.delete_forever_rounded;
      case _NoticeKind.error:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: notice.actionPath == null ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [darkGreen.withValues(alpha: 0.96), richBlack],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(_icon(), color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    notice.message,
                    style: const TextStyle(
                      color: antiFlashWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (notice.actionPath != null)
                  Icon(
                    Icons.folder_open_rounded,
                    color: antiFlashWhite.withValues(alpha: 0.88),
                    size: 18,
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: antiFlashWhite.withValues(alpha: 0.85),
                    size: 18,
                  ),
                  splashRadius: 18,
                  tooltip: 'Dismiss',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecentTreeScan {
  final String treeId;
  final DateTime scannedAt;
  final MangroveTree tree;
  final double metersPerPixel;
  final String? capturedImagePath;
  final Uint8List? rootMaskBytes;
  final int? rootMaskWidth;
  final int? rootMaskHeight;
  final Uint8List? trunkMaskBytes;
  final int? trunkMaskWidth;
  final int? trunkMaskHeight;

  const RecentTreeScan({
    required this.treeId,
    required this.scannedAt,
    required this.tree,
    this.metersPerPixel = 0.003,
    this.capturedImagePath,
    this.rootMaskBytes,
    this.rootMaskWidth,
    this.rootMaskHeight,
    this.trunkMaskBytes,
    this.trunkMaskWidth,
    this.trunkMaskHeight,
  });

  int get rootCount => tree.roots.length;
  double get trunkWidthMeters => tree.trunkWidthPixels * metersPerPixel;
  double get rootSpreadMeters => tree.rootSpreadPixels * metersPerPixel;
  double get trunkWidthCentimeters => trunkWidthMeters * 100;
  double get rootSpreadCentimeters => rootSpreadMeters * 100;
  double get stabilityIndex => tree.stabilityIndex;
  double get stabilityScore => tree.stabilityScore;
  double get symmetryScore => tree.symmetryScore;
  double get rootCoverageRatio => tree.stabilityMetrics.rootCoverageRatio;
  StabilityAssessment get assessment => tree.assessment;

  Map<String, dynamic> toJson() {
    final maskBytes = rootMaskBytes;
    final maskWidth = rootMaskWidth;
    final maskHeight = rootMaskHeight;
    final trunkBytes = trunkMaskBytes;
    final trunkWidth = trunkMaskWidth;
    final trunkHeight = trunkMaskHeight;
    return {
      'treeId': treeId,
      'scannedAt': scannedAt.toIso8601String(),
      'metersPerPixel': metersPerPixel,
      if (capturedImagePath != null) 'capturedImagePath': capturedImagePath,
      if (maskBytes != null && maskWidth != null && maskHeight != null)
        'rootMask': {
          'width': maskWidth,
          'height': maskHeight,
          'data': base64Encode(maskBytes),
        },
      if (trunkBytes != null && trunkWidth != null && trunkHeight != null)
        'trunkMask': {
          'width': trunkWidth,
          'height': trunkHeight,
          'data': base64Encode(trunkBytes),
        },
      'tree': {
        'trunkWidthAtBranchPoint': tree.trunkWidthAtBranchPoint,
        if (tree.trunkMeasurement != null)
          'trunkMeasurement': {
            'startX': tree.trunkMeasurement!.startX,
            'endX': tree.trunkMeasurement!.endX,
            'y': tree.trunkMeasurement!.y,
            'isEstimated': tree.trunkMeasurement!.isEstimated,
          },
        if (tree.treeBounds != null)
          'treeBounds': {
            'left': tree.treeBounds!.left,
            'top': tree.treeBounds!.top,
            'right': tree.treeBounds!.right,
            'bottom': tree.treeBounds!.bottom,
          },
        'roots': tree.roots
            .map(
              (root) => {
                'dx': root.position.dx,
                'dy': root.position.dy,
                'length': root.length,
                'angle': root.angle,
                if (root.normalizedLeft != null)
                  'normalizedLeft': root.normalizedLeft,
                if (root.normalizedTop != null)
                  'normalizedTop': root.normalizedTop,
                if (root.normalizedRight != null)
                  'normalizedRight': root.normalizedRight,
                if (root.normalizedBottom != null)
                  'normalizedBottom': root.normalizedBottom,
              },
            )
            .toList(growable: false),
      },
    };
  }

  factory RecentTreeScan.fromJson(Map<String, dynamic> json) {
    final treeMap = (json['tree'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rootsRaw = (treeMap['roots'] as List?) ?? const [];
    final roots = rootsRaw
        .whereType<Map>()
        .map((rootMap) {
          final typed = rootMap.cast<String, dynamic>();
          return Root(
            position: Offset(
              (typed['dx'] as num?)?.toDouble() ?? 0,
              (typed['dy'] as num?)?.toDouble() ?? 0,
            ),
            length: (typed['length'] as num?)?.toDouble() ?? 0,
            angle: (typed['angle'] as num?)?.toDouble() ?? 0,
            normalizedLeft: (typed['normalizedLeft'] as num?)?.toDouble(),
            normalizedTop: (typed['normalizedTop'] as num?)?.toDouble(),
            normalizedRight: (typed['normalizedRight'] as num?)?.toDouble(),
            normalizedBottom: (typed['normalizedBottom'] as num?)?.toDouble(),
          );
        })
        .toList(growable: false);

    final trunkMeasurementRaw = (treeMap['trunkMeasurement'] as Map?)
        ?.cast<String, dynamic>();
    TrunkMeasurement? trunkMeasurement;
    if (trunkMeasurementRaw != null) {
      final startX = (trunkMeasurementRaw['startX'] as num?)?.toDouble();
      final endX = (trunkMeasurementRaw['endX'] as num?)?.toDouble();
      final y = (trunkMeasurementRaw['y'] as num?)?.toDouble();
      final isEstimated = (trunkMeasurementRaw['isEstimated'] as bool?) ?? true;
      if (startX != null && endX != null && y != null) {
        trunkMeasurement = TrunkMeasurement(
          startX: startX,
          endX: endX,
          y: y,
          isEstimated: isEstimated,
        );
      }
    }

    final treeBoundsRaw = (treeMap['treeBounds'] as Map?)
        ?.cast<String, dynamic>();
    TreeBounds? treeBounds;
    if (treeBoundsRaw != null) {
      final left = (treeBoundsRaw['left'] as num?)?.toDouble();
      final top = (treeBoundsRaw['top'] as num?)?.toDouble();
      final right = (treeBoundsRaw['right'] as num?)?.toDouble();
      final bottom = (treeBoundsRaw['bottom'] as num?)?.toDouble();
      if (left != null && top != null && right != null && bottom != null) {
        treeBounds = TreeBounds(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        );
      }
    }

    final rootMaskRaw = (json['rootMask'] as Map?)?.cast<String, dynamic>();
    Uint8List? rootMaskBytes;
    int? rootMaskWidth;
    int? rootMaskHeight;
    if (rootMaskRaw != null) {
      final width = (rootMaskRaw['width'] as num?)?.toInt();
      final height = (rootMaskRaw['height'] as num?)?.toInt();
      final data = rootMaskRaw['data'] as String?;
      if (width != null &&
          height != null &&
          data != null &&
          data.trim().isNotEmpty) {
        try {
          rootMaskBytes = base64Decode(data);
          rootMaskWidth = width;
          rootMaskHeight = height;
        } catch (_) {
          rootMaskBytes = null;
          rootMaskWidth = null;
          rootMaskHeight = null;
        }
      }
    }

    final trunkMaskRaw = (json['trunkMask'] as Map?)?.cast<String, dynamic>();
    Uint8List? trunkMaskBytes;
    int? trunkMaskWidth;
    int? trunkMaskHeight;
    if (trunkMaskRaw != null) {
      final width = (trunkMaskRaw['width'] as num?)?.toInt();
      final height = (trunkMaskRaw['height'] as num?)?.toInt();
      final data = trunkMaskRaw['data'] as String?;
      if (width != null &&
          height != null &&
          data != null &&
          data.trim().isNotEmpty) {
        try {
          trunkMaskBytes = base64Decode(data);
          trunkMaskWidth = width;
          trunkMaskHeight = height;
        } catch (_) {
          trunkMaskBytes = null;
          trunkMaskWidth = null;
          trunkMaskHeight = null;
        }
      }
    }

    final scannedAtRaw = json['scannedAt'] as String?;
    return RecentTreeScan(
      treeId: (json['treeId'] as String?)?.trim().isNotEmpty == true
          ? json['treeId'] as String
          : 'Tree',
      scannedAt: scannedAtRaw == null
          ? DateTime.now()
          : (DateTime.tryParse(scannedAtRaw) ?? DateTime.now()),
      metersPerPixel: (json['metersPerPixel'] as num?)?.toDouble() ?? 0.003,
      capturedImagePath:
          ((json['capturedImagePath'] as String?)?.trim().isNotEmpty ?? false)
          ? (json['capturedImagePath'] as String).trim()
          : null,
      rootMaskBytes: rootMaskBytes,
      rootMaskWidth: rootMaskWidth,
      rootMaskHeight: rootMaskHeight,
      trunkMaskBytes: trunkMaskBytes,
      trunkMaskWidth: trunkMaskWidth,
      trunkMaskHeight: trunkMaskHeight,
      tree: MangroveTree(
        trunkWidthAtBranchPoint:
            (treeMap['trunkWidthAtBranchPoint'] as num?)?.toDouble() ?? 0,
        roots: roots,
        trunkMeasurement: trunkMeasurement,
        treeBounds: treeBounds,
      ),
    );
  }
}

class _EmptyRecentScanCard extends StatelessWidget {
  const _EmptyRecentScanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkGreen.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bangladeshGreen.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: caribbeanGreen.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tips_and_updates_rounded,
              color: caribbeanGreen.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No recent scans yet. Capture a mangrove scan to see results here.',
              style: TextStyle(
                color: antiFlashWhite,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableScanCard extends StatelessWidget {
  final RecentTreeScan scan;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _ExpandableScanCard({
    required this.scan,
    required this.expanded,
    required this.onTap,
    required this.onSave,
    required this.onDelete,
  });

  Color _statusColor() {
    switch (scan.assessment) {
      case StabilityAssessment.high:
        return caribbeanGreen;
      case StabilityAssessment.moderate:
        return const Color(0xFFF59E0B);
      case StabilityAssessment.low:
        return const Color(0xFFEF4444);
      case StabilityAssessment.veryUnstable:
        return const Color(0xFFB91C1C);
    }
  }

  String _formatTimestamp(DateTime value) {
    final hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    final month = _monthName(value.month);
    return '$month ${value.day}, ${value.year} • $hour12:$minute $period';
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final score = scan.stabilityScore;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: expanded
                  ? [bangladeshGreen.withValues(alpha: 0.8), darkGreen]
                  : [darkGreen, darkGreen.withValues(alpha: 0.94)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: expanded
                  ? statusColor.withValues(alpha: 0.8)
                  : bangladeshGreen.withValues(alpha: 0.9),
              width: expanded ? 1.6 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: expanded ? 0.22 : 0.1),
                blurRadius: expanded ? 14 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mangrove Stability:',
                    style: TextStyle(
                      color: antiFlashWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.58),
                      ),
                    ),
                    child: Text(
                      _stabilityLabel(scan.assessment),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatTimestamp(scan.scannedAt),
                style: TextStyle(
                  color: antiFlashWhite.withValues(alpha: 0.62),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(label: 'Root Count', value: '${scan.rootCount}'),
                  _MetricChip(
                    label: 'Root Spread',
                    value:
                        '${scan.rootSpreadCentimeters.toStringAsFixed(1)} cm',
                  ),
                ],
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(title: 'Stability Details'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: richBlack.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: bangladeshGreen.withValues(
                                      alpha: 0.92,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _DetailRow(
                                      label: 'Detected Roots',
                                      value: '${scan.rootCount}',
                                    ),
                                    const SizedBox(height: 6),
                                    _DetailRow(
                                      label: 'Root Spread',
                                      value:
                                          '${scan.rootSpreadCentimeters.toStringAsFixed(1)} cm',
                                    ),
                                    const SizedBox(height: 6),
                                    _DetailRow(
                                      label: 'Stability Score',
                                      value: score.toStringAsFixed(2),
                                      emphasize: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Stability Score (0–1): ${score.toStringAsFixed(2)}'
                                  ' • Symmetry: ${scan.symmetryScore.toStringAsFixed(2)}'
                                  ' • Coverage: ${scan.rootCoverageRatio.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: antiFlashWhite.withValues(
                                      alpha: 0.88,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  _ThresholdChip(
                                    label: 'High (0.75–1.00)',
                                    active:
                                        scan.assessment ==
                                        StabilityAssessment.high,
                                    color: caribbeanGreen,
                                  ),
                                  _ThresholdChip(
                                    label: 'Moderate (0.50–0.74)',
                                    active:
                                        scan.assessment ==
                                        StabilityAssessment.moderate,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                  _ThresholdChip(
                                    label: 'Low (0.25–0.49)',
                                    active:
                                        scan.assessment ==
                                        StabilityAssessment.low,
                                    color: const Color(0xFFEF4444),
                                  ),
                                  _ThresholdChip(
                                    label: 'Very Unstable (0.00–0.24)',
                                    active:
                                        scan.assessment ==
                                        StabilityAssessment.veryUnstable,
                                    color: const Color(0xFFB91C1C),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                scan.assessment.description,
                                style: TextStyle(
                                  color: antiFlashWhite.withValues(alpha: 0.76),
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF064E3B),
                                            Color(0xFF10B981),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF86EFAC,
                                          ).withValues(alpha: 0.34),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.24),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: FilledButton(
                                          onPressed: onSave,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: antiFlashWhite,
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.zero,
                                            ),
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.picture_as_pdf_rounded,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Export'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF7F1D1D),
                                            Color(0xFFDC2626),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFCA5A5,
                                          ).withValues(alpha: 0.32),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFEF4444,
                                            ).withValues(alpha: 0.26),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: FilledButton(
                                          onPressed: onDelete,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: antiFlashWhite,
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.zero,
                                            ),
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.delete_forever_rounded,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Delete'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: richBlack.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: bangladeshGreen.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: antiFlashWhite.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: antiFlashWhite,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            richBlack.withValues(alpha: 0.7),
            darkGreen.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withValues(alpha: 0.6)),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: antiFlashWhite.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: antiFlashWhite,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.1),
                  accent.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: antiFlashWhite.withValues(alpha: 0.86),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: antiFlashWhite.withValues(alpha: 0.74),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: antiFlashWhite,
            fontSize: emphasize ? 12 : 11,
            fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ThresholdChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;

  const _ThresholdChip({
    required this.label,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.75)
              : antiFlashWhite.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? color : antiFlashWhite.withValues(alpha: 0.75),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
