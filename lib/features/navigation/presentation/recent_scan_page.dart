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

enum RecentScanNoticeKind { success, delete, error }

class RecentScanNotice {
  final int id;
  final String message;
  final RecentScanNoticeKind kind;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const RecentScanNotice({
    required this.id,
    required this.message,
    required this.kind,
    this.actionLabel,
    this.onAction,
  });
}

String _stabilityLabel(StabilityAssessment assessment) {
  return assessment.label;
}

String _stormCategory(StabilityAssessment assessment) {
  switch (assessment) {
    case StabilityAssessment.high:
      return 'Signal No. 1-2';
    case StabilityAssessment.moderate:
      return 'Tropical Storm';
    case StabilityAssessment.low:
      return 'Tropical Depression';
  }
}

String _recentScanSummary(StabilityAssessment assessment) {
  final stormCategory = _stormCategory(assessment);
  return 'Based on the detection, the root structure acts as an anchor by '
      'distributing load and gripping sediment. ${assessment.label} indicates '
      '$stormCategory resistance for the recent scan.';
}

class RecentScanPage extends StatefulWidget {
  final ValueListenable<List<RecentTreeScan>> scansListenable;
  final ValueListenable<RecentScanNotice?>? noticeListenable;
  final Future<String?> Function(int index)? onSaveScan;
  final Future<void> Function(int index)? onDeleteScan;
  final Future<bool> Function(String pdfPath)? onOpenExportPath;
  final VoidCallback? onRescan;

  const RecentScanPage({
    super.key,
    required this.scansListenable,
    this.noticeListenable,
    this.onSaveScan,
    this.onDeleteScan,
    this.onOpenExportPath,
    this.onRescan,
  });

  @override
  State<RecentScanPage> createState() => _RecentScanPageState();
}

class _RecentScanPageState extends State<RecentScanPage> {
  bool _peekRawPhoto = false;
  final Map<String, Size> _imageSizeCache = {};
  VoidCallback? _noticeListener;
  int? _lastNoticeId;

  @override
  void initState() {
    super.initState();
    _attachNoticeListener();
  }

  @override
  void didUpdateWidget(covariant RecentScanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noticeListenable != widget.noticeListenable) {
      _detachNoticeListener(oldWidget.noticeListenable);
      _attachNoticeListener();
    }
  }

  @override
  void dispose() {
    _detachNoticeListener();
    super.dispose();
  }

  void _attachNoticeListener() {
    final listenable = widget.noticeListenable;
    if (listenable == null) return;

    void handleNotice() {
      final notice = listenable.value;
      if (notice == null || notice.id == _lastNoticeId) return;
      _lastNoticeId = notice.id;
      _showNotice(
        message: notice.message,
        kind: _mapNoticeKind(notice.kind),
        actionLabel: notice.actionLabel,
        onAction: notice.onAction,
      );
    }

    _noticeListener = handleNotice;
    listenable.addListener(handleNotice);
    handleNotice();
  }

  void _detachNoticeListener([ValueListenable<RecentScanNotice?>? listenable]) {
    final target = listenable ?? widget.noticeListenable;
    final listener = _noticeListener;
    if (target != null && listener != null) {
      target.removeListener(listener);
    }
    _noticeListener = null;
  }

  _NoticeKind _mapNoticeKind(RecentScanNoticeKind kind) {
    switch (kind) {
      case RecentScanNoticeKind.success:
        return _NoticeKind.success;
      case RecentScanNoticeKind.delete:
        return _NoticeKind.delete;
      case RecentScanNoticeKind.error:
        return _NoticeKind.error;
    }
  }

  Future<void> _handleSaveScan(int index) async {
    final saveCallback = widget.onSaveScan;
    if (saveCallback == null) return;

    final exportedPdfPath = await saveCallback(index);
    if (!mounted) return;
    final filename = exportedPdfPath?.split('/').last;
    if (filename == null) {
      _showNotice(
        message: 'PDF export failed. Try a full app restart.',
        kind: _NoticeKind.error,
      );
      return;
    }

    final safePath = exportedPdfPath!;
    _showNotice(
      message: 'Saved to Downloads/MangroveGuard • $filename',
      kind: _NoticeKind.success,
      actionLabel: 'Open',
      onAction: () async {
        final openCallback = widget.onOpenExportPath;
        if (openCallback == null) return;
        try {
          final opened = await openCallback(safePath);
          if (!mounted) return;
          if (!opened) {
            _showNotice(
              message: 'Unable to open the PDF. Try from Downloads.',
              kind: _NoticeKind.error,
            );
          }
        } catch (_) {
          if (!mounted) return;
          _showNotice(
            message: 'Unable to open the PDF. Try from Downloads.',
            kind: _NoticeKind.error,
          );
        }
      },
    );
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

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (image) {
      if (!completer.isCompleted) {
        completer.complete(image);
      }
    });
    return completer.future;
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

  List<Rect> _normalizedMangroveRects(MangroveTree tree) {
    final bounds = tree.treeBounds;
    if (bounds != null) {
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

    final rootRects = _normalizedRootRects(tree);
    if (rootRects.isEmpty) return const [];
    var minL = 1.0;
    var minT = 1.0;
    var maxR = 0.0;
    var maxB = 0.0;
    for (final rect in rootRects) {
      minL = math.min(minL, rect.left);
      minT = math.min(minT, rect.top);
      maxR = math.max(maxR, rect.right);
      maxB = math.max(maxB, rect.bottom);
    }
    return [
      Rect.fromLTRB(
        minL.clamp(0.0, 1.0),
        minT.clamp(0.0, 1.0),
        maxR.clamp(0.0, 1.0),
        maxB.clamp(0.0, 1.0),
      ),
    ];
  }

  void _showNotice({
    required String message,
    required _NoticeKind kind,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'notification',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        });

        final accentColor = _noticeAccentColor(kind);
        final actionText = actionLabel?.trim();
        final hasAction =
            actionText != null && actionText.isNotEmpty && onAction != null;

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: darkGreen.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _noticeIcon(kind),
                        color: accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: antiFlashWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasAction) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: accentColor.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          onPressed: () async {
                            if (navigator.canPop()) {
                              navigator.pop();
                            }
                            await onAction();
                          },
                          child: Text(
                            actionText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.2),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
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
    }
  }

  Color _noticeAccentColor(_NoticeKind kind) {
    switch (kind) {
      case _NoticeKind.success:
        return caribbeanGreen;
      case _NoticeKind.delete:
        return const Color(0xFFEF4444);
      case _NoticeKind.error:
        return const Color(0xFFF97316);
    }
  }

  IconData _noticeIcon(_NoticeKind kind) {
    switch (kind) {
      case _NoticeKind.success:
        return Icons.picture_as_pdf_rounded;
      case _NoticeKind.delete:
        return Icons.delete_forever_rounded;
      case _NoticeKind.error:
        return Icons.error_outline_rounded;
    }
  }

  double _scannerFrameAspect(Size size) {
    return _scannerFrameAspectForSize(size);
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
              return const _EmptyRecentScanCard();
            }

            final scan = scans.first;
            final imagePath = scan.capturedImagePath?.trim();
            final hasImage = imagePath != null && imagePath.isNotEmpty;
            final statusColor = _assessmentColor(scan.assessment);
            final stabilityRatio = scan.stabilityScore.clamp(0.0, 1.0);
            final photoBorderWidth = 1.5 + ((1.0 - stabilityRatio) * 3.5);
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
            final mangroveRects = _normalizedMangroveRects(scan.tree);
            final hasAnyHighlight = mangroveRects.isNotEmpty;
            final hasPrediction = scan.predictedAssessment != null;
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
                              child: Stack(
                                children: [
                                  Positioned.fill(
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
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Container(
                                                        color: darkGreen
                                                            .withValues(
                                                              alpha: 0.55,
                                                            ),
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons
                                                                .broken_image_rounded,
                                                            color:
                                                                antiFlashWhite,
                                                            size: 36,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  if (showHighlights &&
                                                      mangroveRects.isNotEmpty)
                                                    CustomPaint(
                                                      painter:
                                                          _RootHighlightPainter(
                                                            rects:
                                                                mangroveRects,
                                                            color:
                                                                caribbeanGreen,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                        : Container(
                                            color: darkGreen.withValues(
                                              alpha: 0.55,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.image_rounded,
                                                color: antiFlashWhite,
                                                size: 36,
                                              ),
                                            ),
                                          ),
                                  ),
                                  if (hasImage &&
                                      (hasAnyHighlight || hasPrediction))
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: _DetectionBadge(
                                        accent: statusColor,
                                        stabilityLabel:
                                            _stabilityLabel(scan.assessment),
                                      ),
                                    ),
                                  if (hasImage && hasAnyHighlight)
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: _PeekHighlightButton(
                                        pressed: _peekRawPhoto,
                                        onPressedChanged: (pressed) {
                                          if (!mounted) return;
                                          setState(
                                            () => _peekRawPhoto = pressed,
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasImage && hasAnyHighlight) ...[
                    const SizedBox(height: 10),
                    _HighlightLegend(
                      showHighlights: showHighlights,
                      label: 'Mangrove detected',
                    ),
                    const SizedBox(height: 12),
                  ] else
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
                        Text(
                          _recentScanSummary(scan.assessment),
                          style: TextStyle(
                            color: antiFlashWhite.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
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

double _scannerFrameAspectForSize(Size size) {
  final frameWidth = (size.width * 0.82).clamp(280.0, 340.0);
  final frameHeight = (size.height * 0.5).clamp(320.0, 420.0);
  final innerWidth = (frameWidth - 30).clamp(250.0, 305.0);
  final innerHeight = (frameHeight - 28).clamp(290.0, 385.0);
  return innerWidth / innerHeight;
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
    final semanticLabel = pressed ? 'Show overlay' : 'Hide overlay';
    final labelColor = antiFlashWhite.withValues(alpha: pressed ? 0.78 : 0.86);
    return Semantics(
      label: semanticLabel,
      button: true,
      toggled: pressed,
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
              onTap: () => onPressedChanged(!pressed),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pressed
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                      color: antiFlashWhite.withValues(
                        alpha: pressed ? 0.96 : 0.86,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Overlay',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetectionBadge extends StatelessWidget {
  final Color accent;
  final String stabilityLabel;

  const _DetectionBadge({
    required this.accent,
    required this.stabilityLabel,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            darkGreen.withValues(alpha: 0.85),
            richBlack.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_rounded, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  'Mangrove detected',
                  style: TextStyle(
                    color: antiFlashWhite.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stabilityLabel,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightLegend extends StatelessWidget {
  final bool showHighlights;
  final String label;

  const _HighlightLegend({
    required this.showHighlights,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = antiFlashWhite.withValues(
      alpha: showHighlights ? 0.82 : 0.62,
    );
    final borderColor = bangladeshGreen.withValues(
      alpha: showHighlights ? 0.55 : 0.35,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            darkGreen.withValues(alpha: 0.78),
            richBlack.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            showHighlights ? 'Overlay' : 'Overlay (hidden)',
            style: TextStyle(
              color: labelColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          _HighlightLegendChip(
            color: caribbeanGreen,
            label: label,
            dim: !showHighlights,
          ),
        ],
      ),
    );
  }
}

class _HighlightLegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool dim;

  const _HighlightLegendChip({
    required this.color,
    required this.label,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = dim ? color.withValues(alpha: 0.6) : color;
    final textColor = antiFlashWhite.withValues(alpha: dim ? 0.68 : 0.86);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dim ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dotColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _NoticeKind { success, delete, error }

class RecentTreeScan {
  final String treeId;
  final DateTime scannedAt;
  final MangroveTree tree;
  final double metersPerPixel;
  final double? predictionConfidence;
  final StabilityAssessment? predictedAssessment;
  final String? capturedImagePath;

  const RecentTreeScan({
    required this.treeId,
    required this.scannedAt,
    required this.tree,
    this.metersPerPixel = 0.003,
    this.predictionConfidence,
    this.predictedAssessment,
    this.capturedImagePath,
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
  StabilityAssessment get assessment => predictedAssessment ?? tree.assessment;

  static double _assessmentScore(StabilityAssessment assessment) {
    switch (assessment) {
      case StabilityAssessment.high:
        return 1.0;
      case StabilityAssessment.moderate:
        return 0.5;
      case StabilityAssessment.low:
        return 0.0;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'treeId': treeId,
      'scannedAt': scannedAt.toIso8601String(),
      'metersPerPixel': metersPerPixel,
      if (predictionConfidence != null)
        'predictionConfidence': predictionConfidence,
      if (predictedAssessment != null)
        'predictedAssessment': predictedAssessment!.name,
      if (capturedImagePath != null) 'capturedImagePath': capturedImagePath,
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

    final scannedAtRaw = json['scannedAt'] as String?;
    final predictedAssessmentRaw = json['predictedAssessment'] as String?;
    StabilityAssessment? predictedAssessment;
    if (predictedAssessmentRaw != null) {
      for (final assessment in StabilityAssessment.values) {
        if (assessment.name == predictedAssessmentRaw) {
          predictedAssessment = assessment;
          break;
        }
      }
    }
    return RecentTreeScan(
      treeId: (json['treeId'] as String?)?.trim().isNotEmpty == true
          ? json['treeId'] as String
          : 'Tree',
      scannedAt: scannedAtRaw == null
          ? DateTime.now()
          : (DateTime.tryParse(scannedAtRaw) ?? DateTime.now()),
      metersPerPixel: (json['metersPerPixel'] as num?)?.toDouble() ?? 0.003,
      predictionConfidence:
          (json['predictionConfidence'] as num?)?.toDouble(),
      predictedAssessment: predictedAssessment,
      capturedImagePath:
          ((json['capturedImagePath'] as String?)?.trim().isNotEmpty ?? false)
          ? (json['capturedImagePath'] as String).trim()
          : null,
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
    final padding = MediaQuery.paddingOf(context);
    const bottomNavHeight = 112.0;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  richBlack,
                  darkGreen.withValues(alpha: 0.9),
                  richBlack,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, padding.top + 12, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bangladeshGreen.withValues(alpha: 0.2),
                      border: Border.all(
                        color: bangladeshGreen.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.search_off_rounded,
                      size: 34,
                      color: caribbeanGreen.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No scans yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: antiFlashWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture a mangrove scan to see results here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: antiFlashWhite.withValues(alpha: 0.7),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: bottomNavHeight + 12),
                ],
              ),
            ),
          ),
        ),
      ],
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
