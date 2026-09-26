import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mangrove_tree.dart';
import '../services/monitoring_sync_service.dart';

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

String _recentScanSummary(StabilityAssessment assessment) {
  switch (assessment) {
    case StabilityAssessment.high:
      return 'This mangrove shows High Stability. It acts as a primary defense line, capable of absorbing heavy wave energy and resisting gale-force winds. Its deep, interlocking root system makes it highly unlikely to uproot during a storm. This dense underground network anchors the tree firmly while dissipating the force of powerful surges to protect the coastline.';
    case StabilityAssessment.moderate:
      return 'This mangrove shows Moderate Stability. While it offers decent protection, it may suffer branch breakage or partial root loosening during a strong storm. It can handle moderate winds, but it needs surrounding support to stay upright in a typhoon. Its structural resilience depends heavily on the presence of neighboring trees to help buffer high-velocity gusts.';
    case StabilityAssessment.low:
      return 'This mangrove has Low Stability. It provides minimal protection against storm surges and is at high risk of being uprooted by strong winds. In its current state, it may not survive a major weather event and could even become floating debris. The lack of a developed root base means it cannot withstand significant environmental pressure or effectively grip the shifting soil.';
  }
}

class RecentScanPage extends StatefulWidget {
  final ValueListenable<List<RecentTreeScan>> scansListenable;
  final ValueListenable<RecentScanNotice?>? noticeListenable;
  final Future<void> Function(int index)? onDeleteScan;
  final VoidCallback? onRescan;
  final Future<bool> Function(int index)? onUploadScan;
  final VoidCallback? onClearQueue;

  const RecentScanPage({
    super.key,
    required this.scansListenable,
    this.noticeListenable,
    this.onDeleteScan,
    this.onRescan,
    this.onUploadScan,
    this.onClearQueue,
  });

  @override
  State<RecentScanPage> createState() => _RecentScanPageState();
}

class _RecentScanPageState extends State<RecentScanPage> {
  bool _peekRawPhoto = false;
  final Map<String, Size> _imageSizeCache = {};
  VoidCallback? _noticeListener;
  int? _lastNoticeId;
  final Set<int> _uploadingIndices = {};
  final Set<String> _failedUploadTreeIds = {};
  bool _uploadAttempted = false;
  String? _currentDisplayedTreeId;

  static const double _connectionPullTrigger = 70;
  static const double _connectionPullDisarm = 52;
  static const double _connectionPullMaxExtent = 72;
  static const double _connectionMinIntentDrag = 96;
  static const double _connectionIndicatorBottom = 114;

  double _connectionPullExtent = 0;
  double _connectionDragDistance = 0;
  bool _connectionTriggerArmed = false;
  bool _connectionReleaseQueued = false;
  bool _connectionSheetOpen = false;
  bool _connectionSheetPending = false;
  bool _showConnectionHint = false;
  bool _connectionHintSeen = false;
  Timer? _connectionHintTimer;

  @override
  void initState() {
    super.initState();
    _attachNoticeListener();
    widget.scansListenable.addListener(_onScansChanged);
    _onScansChanged();
  }

  @override
  void didUpdateWidget(covariant RecentScanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noticeListenable != widget.noticeListenable) {
      _detachNoticeListener(oldWidget.noticeListenable);
      _attachNoticeListener();
    }
    if (oldWidget.scansListenable != widget.scansListenable) {
      oldWidget.scansListenable.removeListener(_onScansChanged);
      widget.scansListenable.addListener(_onScansChanged);
      _onScansChanged();
    }
  }

  @override
  void dispose() {
    widget.scansListenable.removeListener(_onScansChanged);
    _detachNoticeListener();
    super.dispose();
  }

  void _onScansChanged() {
    final scans = widget.scansListenable.value;
    final firstTreeId = scans.isEmpty ? null : scans.first.treeId;
    if (_currentDisplayedTreeId != firstTreeId) {
      _currentDisplayedTreeId = firstTreeId;
      _uploadAttempted = false;
      if (mounted) {
        setState(() {});
      }
    }
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

  void _showConnectionHintNotice() {
    if (_connectionHintSeen) {
      return;
    }
    _connectionHintSeen = true;
    _connectionHintTimer?.cancel();
    if (mounted) {
      setState(() {
        _showConnectionHint = true;
      });
    }
    _connectionHintTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showConnectionHint = false;
      });
    });
  }

  bool _handleConnectionScrollNotification(
    ScrollNotification notification,
    BuildContext context,
  ) {
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _connectionDragDistance = 0;
      _connectionReleaseQueued = false;
      return false;
    }

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      if (!_connectionHintSeen &&
          metrics.maxScrollExtent > 0 &&
          metrics.pixels >= metrics.maxScrollExtent - 24 &&
          !_connectionSheetOpen) {
        _showConnectionHintNotice();
      }

      final dragDelta = switch (notification) {
        ScrollUpdateNotification update => update.dragDetails?.primaryDelta,
        OverscrollNotification overscroll =>
          overscroll.dragDetails?.primaryDelta,
        _ => null,
      };
      final isDraggingUp = dragDelta != null && dragDelta < 0;
      final isDraggingDown = dragDelta != null && dragDelta > 0;
      if (dragDelta != null) {
        if (dragDelta < 0) {
          _connectionDragDistance = (_connectionDragDistance + -dragDelta)
              .clamp(0.0, _connectionPullMaxExtent * 2)
              .toDouble();
        } else if (dragDelta > 0 && _connectionDragDistance > 0) {
          _connectionDragDistance = (_connectionDragDistance - dragDelta)
              .clamp(0.0, _connectionPullMaxExtent * 2)
              .toDouble();
        }
      }

      final isPushingPastBottom = metrics.pixels > metrics.maxScrollExtent;
      final isReversingIntoList = !isPushingPastBottom && isDraggingDown;
      if (isReversingIntoList &&
          (_connectionPullExtent > 0 ||
              _connectionTriggerArmed ||
              _connectionReleaseQueued)) {
        setState(() {
          _connectionPullExtent = 0;
          _connectionTriggerArmed = false;
          _connectionReleaseQueued = false;
        });
        _connectionDragDistance = 0;
        return false;
      }

      if (isPushingPastBottom) {
        final rawPullExtent = (metrics.pixels - metrics.maxScrollExtent)
            .clamp(0.0, _connectionPullMaxExtent)
            .toDouble();
        final pullExtent = rawPullExtent > _connectionDragDistance
            ? _connectionDragDistance
            : rawPullExtent;
        final hasIntentionalDrag =
            _connectionDragDistance >= _connectionMinIntentDrag;
        final armed =
            (_connectionTriggerArmed && pullExtent >= _connectionPullDisarm) ||
            (isDraggingUp &&
                hasIntentionalDrag &&
                pullExtent >= _connectionPullTrigger);
        var releaseQueued = _connectionReleaseQueued || armed;

        if (isDraggingDown && pullExtent < _connectionPullTrigger) {
          releaseQueued = false;
        }

        if (dragDelta == null && releaseQueued && !_connectionSheetOpen) {
          setState(() {
            _connectionPullExtent = 0;
            _connectionTriggerArmed = false;
            _connectionReleaseQueued = false;
          });
          _connectionDragDistance = 0;
          _showConnectionSheet(context);
          return false;
        }

        if (pullExtent != _connectionPullExtent ||
            armed != _connectionTriggerArmed ||
            releaseQueued != _connectionReleaseQueued) {
          setState(() {
            _connectionPullExtent = pullExtent;
            _connectionTriggerArmed = armed;
            _connectionReleaseQueued = releaseQueued;
          });
        }
      } else if (_connectionPullExtent > 0 ||
          _connectionTriggerArmed ||
          _connectionReleaseQueued) {
        setState(() {
          _connectionPullExtent = 0;
          _connectionTriggerArmed = false;
          _connectionReleaseQueued = false;
        });
      }
    } else if (notification is ScrollEndNotification) {
      final shouldShowSheet =
          (_connectionTriggerArmed || _connectionReleaseQueued) &&
              !_connectionSheetOpen;
      if (_connectionPullExtent > 0 ||
          _connectionTriggerArmed ||
          _connectionReleaseQueued) {
        setState(() {
          _connectionPullExtent = 0;
          _connectionTriggerArmed = false;
          _connectionReleaseQueued = false;
        });
      }
      _connectionDragDistance = 0;
      if (shouldShowSheet) {
        _showConnectionSheet(context);
      }
    }

    return false;
  }

  Future<void> _showConnectionSheet(BuildContext context) async {
    if (_connectionSheetOpen || _connectionSheetPending) {
      return;
    }
    _connectionSheetPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _connectionSheetPending = false;
        return;
      }
      _connectionSheetPending = false;
      if (_connectionSheetOpen) {
        return;
      }

      _connectionHintTimer?.cancel();
      if (_showConnectionHint) {
        setState(() {
          _showConnectionHint = false;
        });
      }

      _connectionSheetOpen = true;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _ConnectionStatusSheet(
          scansListenable: widget.scansListenable,
          onScanSynced: (index) {
            final listenable = widget.scansListenable;
            if (listenable is! ValueNotifier<List<RecentTreeScan>>) return;
            final scans = listenable.value;
            if (index < 0 || index >= scans.length) return;
            final updated = List<RecentTreeScan>.from(scans);
            updated[index] = RecentTreeScan(
              treeId: updated[index].treeId,
              scannedAt: updated[index].scannedAt,
              tree: updated[index].tree,
              predictionConfidence: updated[index].predictionConfidence,
              predictedAssessment: updated[index].predictedAssessment,
              capturedImagePath: updated[index].capturedImagePath,
              isSynced: true,
            );
            listenable.value = updated;
          },
          onClearQueue: widget.onClearQueue,
        ),
      );
      if (mounted) {
        setState(() {
          _connectionSheetOpen = false;
        });
      } else {
        _connectionSheetOpen = false;
      }
    });
  }

  void _handleRescan() {
    final callback = widget.onRescan;
    if (callback == null) return;
    callback();
  }

  Future<void> _handleUploadScan(int index) async {
    if (_uploadAttempted) return;
    final callback = widget.onUploadScan;
    if (callback == null) return;
    final scan = widget.scansListenable.value[index];
    setState(() {
      _uploadingIndices.add(index);
      _failedUploadTreeIds.remove(scan.treeId);
      _uploadAttempted = true;
    });
    try {
      final success = await callback(index);
      if (!mounted) return;
      if (success) {
        _showNotice(
          message: 'Scan uploaded successfully.',
          kind: _NoticeKind.success,
        );
      } else {
        setState(() {
          _failedUploadTreeIds.add(scan.treeId);
        });
        _showNotice(
          message: 'Server unreachable. Scan saved to offline queue.',
          kind: _NoticeKind.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failedUploadTreeIds.add(scan.treeId);
      });
      _showNotice(
        message: 'Upload failed. Please try again.',
        kind: _NoticeKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingIndices.remove(index));
      }
    }
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
    return const [];
  }

  void _showNotice({
    required String message,
    required _NoticeKind kind,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    if (!mounted) return;
    final accentColor = _noticeAccentColor(kind);
    final icon = _noticeIcon(kind);
    final actionText = actionLabel?.trim();
    final hasAction =
        actionText != null && actionText.isNotEmpty && onAction != null;

    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: const Duration(seconds: 1),
      margin: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 10,
        16,
        0,
      ),
      padding: EdgeInsets.zero,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: darkGreen.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.4),
            width: 1,
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
            Icon(icon, color: accentColor, size: 20),
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
                onPressed: () async {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  await onAction();
                },
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
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
        return Icons.check_circle_rounded;
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
            const photoBorderWidth = 3.0;
            final photoBorderColor = statusColor.withValues(alpha: 0.75);
            final topInset = MediaQuery.paddingOf(context).top;
            const extraTopPadding = 30.0;
            final contentTopPadding = topInset + extraTopPadding;
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            const bottomNavHeight = 112.0;
            const extraBottomPadding = 12.0;
            final contentBottomPadding =
                bottomInset + bottomNavHeight + extraBottomPadding;
            final frameAspect =
                _scannerFrameAspect(MediaQuery.sizeOf(context));
            final mangroveRects = _normalizedMangroveRects(scan.tree);
            final hasAnyHighlight = mangroveRects.isNotEmpty;
            final hasPrediction = scan.predictedAssessment != null;
            final showHighlights = !_peekRawPhoto;

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) =>
                  _handleConnectionScrollNotification(notification, context),
              child: Stack(
                children: [
                  StretchingOverscrollIndicator(
                    axisDirection: AxisDirection.down,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        contentTopPadding + 8,
                        16,
                        contentBottomPadding,
                      ),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
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
                                                    future: _loadImageSize(
                                                      imagePath,
                                                    ),
                                                    builder: (
                                                      context,
                                                      snapshot,
                                                    ) {
                                                      final imageSize =
                                                          snapshot.data;
                                                      if (imageSize == null) {
                                                        return Image.file(
                                                          File(imagePath),
                                                          fit: BoxFit.cover,
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
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
                                                        );
                                                      }

                                                      return FittedBox(
                                                        fit: BoxFit.cover,
                                                        alignment:
                                                            Alignment.center,
                                                        child: SizedBox(
                                                          width:
                                                              imageSize.width,
                                                          height:
                                                              imageSize.height,
                                                          child: Stack(
                                                            fit:
                                                                StackFit.expand,
                                                            children: [
                                                              Image.file(
                                                                File(imagePath),
                                                                fit:
                                                                    BoxFit.fill,
                                                                width: imageSize
                                                                    .width,
                                                                height:
                                                                    imageSize
                                                                        .height,
                                                                errorBuilder: (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) {
                                                                  return Container(
                                                                    color: darkGreen
                                                                        .withValues(
                                                                          alpha:
                                                                              0.55,
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
                                                                  mangroveRects
                                                                      .isNotEmpty)
                                                                CustomPaint(
                                                                  painter:
                                                                      _TreeHighlightPainter(
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
                                              (hasAnyHighlight ||
                                                  hasPrediction))
                                            Positioned(
                                              top: 12,
                                              left: 12,
                                              child: _DetectionBadge(
                                                accent: statusColor,
                                                stabilityLabel:
                                                    _stabilityLabel(
                                                  scan.assessment,
                                                ),
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
                                                    () => _peekRawPhoto =
                                                        pressed,
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
                                colors: [
                                  darkGreen.withValues(alpha: 0.95),
                                  richBlack,
                                ],
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
                                        color: statusColor.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.6,
                                          ),
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
                                      color: antiFlashWhite.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimestamp(scan.scannedAt),
                                      style: TextStyle(
                                        color: antiFlashWhite.withValues(
                                          alpha: 0.7,
                                        ),
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
                                    color: antiFlashWhite.withValues(
                                      alpha: 0.85,
                                    ),
                                    fontSize: 12,
                                    height: 1.45,
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
                                              Color(0xFF0F766E),
                                              Color(0xFF14B8A6),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: FilledButton(
                                            onPressed: _handleRescan,
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              foregroundColor: antiFlashWhite,
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              shape:
                                                  const RoundedRectangleBorder(
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
                                                  Icons
                                                      .center_focus_strong_rounded,
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
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: scan.isSynced
                                              ? LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    bangladeshGreen.withValues(
                                                      alpha: 0.7,
                                                    ),
                                                    darkGreen.withValues(
                                                      alpha: 0.85,
                                                    ),
                                                  ],
                                                )
                                              : const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFF03624C),
                                                    Color(0xFF014D3C),
                                                  ],
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: scan.isSynced
                                                ? caribbeanGreen.withValues(
                                                    alpha: 0.45,
                                                  )
                                                : antiFlashWhite.withValues(
                                                    alpha: 0.15,
                                                  ),
                                          ),
                                          boxShadow: scan.isSynced
                                              ? [
                                                  BoxShadow(
                                                    color: caribbeanGreen
                                                        .withValues(
                                                          alpha: 0.18,
                                                        ),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: FilledButton(
                                            onPressed:
                                                scan.isSynced ||
                                                        _uploadAttempted
                                                    ? null
                                                    : () =>
                                                        _handleUploadScan(0),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              disabledBackgroundColor:
                                                  Colors.transparent,
                                              foregroundColor: scan.isSynced
                                                  ? caribbeanGreen
                                                  : antiFlashWhite,
                                              disabledForegroundColor:
                                                  caribbeanGreen,
                                              alignment: Alignment.center,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 12,
                                              ),
                                              shape:
                                                  const RoundedRectangleBorder(
                                                borderRadius: BorderRadius.zero,
                                              ),
                                              textStyle: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            child:
                                                _uploadingIndices.contains(0)
                                                    ? const SizedBox(
                                                        height: 18,
                                                        width: 18,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(
                                                            antiFlashWhite,
                                                          ),
                                                        ),
                                                      )
                                                    : FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              scan.isSynced
                                                                  ? Icons
                                                                      .cloud_done_rounded
                                                                  : _failedUploadTreeIds
                                                                          .contains(
                                                                              scan.treeId)
                                                                      ? Icons
                                                                          .cloud_off_rounded
                                                                      : Icons
                                                                          .cloud_upload_rounded,
                                                              size: 18,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              scan.isSynced
                                                                  ? 'Synced'
                                                                  : _failedUploadTreeIds
                                                                          .contains(
                                                                              scan.treeId)
                                                                      ? 'Pending'
                                                                      : 'Upload',
                                                            ),
                                                          ],
                                                        ),
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
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _connectionIndicatorBottom,
                    child: _ConnectionOverscrollNotice(
                      showHint: _showConnectionHint,
                      pullExtent: _connectionPullExtent,
                      isArmed: _connectionTriggerArmed,
                      hasPending: widget.scansListenable.value.any(
                        (scan) => !scan.isSynced,
                      ),
                      pendingCount: widget.scansListenable.value
                          .where((scan) => !scan.isSynced)
                          .length,
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

class _ConnectionOverscrollNotice extends StatelessWidget {
  final bool showHint;
  final double pullExtent;
  final bool isArmed;
  final bool hasPending;
  final int pendingCount;

  const _ConnectionOverscrollNotice({
    required this.showHint,
    required this.pullExtent,
    required this.isArmed,
    required this.hasPending,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final isPulling = pullExtent > 0;
    final isVisible = isPulling || isArmed || showHint;
    final title = isArmed
        ? 'Release for Server Status'
        : hasPending
            ? 'Pull up for Server Status ($pendingCount Pending)'
            : 'Pull up for Server Status';
    final icon = isArmed
        ? Icons.touch_app_rounded
        : hasPending
            ? Icons.cloud_off_rounded
            : Icons.cloud_done_rounded;
    final iconColor = isArmed
        ? caribbeanGreen
        : hasPending
            ? const Color(0xFFF59E0B)
            : caribbeanGreen;

    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, 0.45),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isVisible ? 1 : 0,
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: (MediaQuery.sizeOf(context).width - 32)
                    .clamp(220.0, 360.0)
                    .toDouble(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: darkGreen.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isArmed
                      ? caribbeanGreen.withValues(alpha: 0.9)
                      : bangladeshGreen.withValues(alpha: 0.9),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: iconColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: antiFlashWhite.withValues(alpha: 0.9),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatusSheet extends StatefulWidget {
  final ValueListenable<List<RecentTreeScan>> scansListenable;
  final void Function(int index) onScanSynced;
  final VoidCallback? onClearQueue;

  const _ConnectionStatusSheet({
    required this.scansListenable,
    required this.onScanSynced,
    this.onClearQueue,
  });

  @override
  State<_ConnectionStatusSheet> createState() => _ConnectionStatusSheetState();
}

class _ConnectionStatusSheetState extends State<_ConnectionStatusSheet> {
  bool _isChecking = true;
  bool _isConnected = false;
  bool _isSyncing = false;
  int _pendingCount = 0;
  String? _endpoint;

  @override
  void initState() {
    super.initState();
    _endpoint = const String.fromEnvironment(
      'MANGROVE_GUARD_API_URL',
      defaultValue: 'http://10.173.168.10:8080',
    );
    widget.scansListenable.addListener(_refreshPendingCount);
    _pendingCount = widget.scansListenable.value.where((scan) => !scan.isSynced).length;
    _checkConnectionAndSync();
  }

  @override
  void dispose() {
    widget.scansListenable.removeListener(_refreshPendingCount);
    super.dispose();
  }

  void _refreshPendingCount() {
    if (!mounted) return;
    final pending = widget.scansListenable.value
        .where((scan) => !scan.isSynced)
        .length;
    setState(() {
      _pendingCount = pending;
    });
  }

  Future<void> _checkConnectionAndSync() async {
    setState(() {
      _isChecking = true;
    });
    final connected = await MonitoringSyncService.pingServer();
    if (!mounted) return;
    setState(() {
      _isConnected = connected;
      _isChecking = false;
    });
  }

  Future<void> _syncPending() async {
    final scans = widget.scansListenable.value;
    final pending = scans.where((scan) => !scan.isSynced).toList();
    if (pending.isEmpty) {
      if (!mounted) return;
      setState(() {
        _pendingCount = 0;
      });
      return;
    }

    setState(() {
      _isSyncing = true;
      _pendingCount = pending.length;
    });

    int syncedCount = 0;
    try {
      await MonitoringSyncService.flushPendingScans(
        scans,
        (index) {
          syncedCount++;
          widget.onScanSynced(index);
        },
      );
    } on SocketException catch (_) {
      if (!mounted) return;
      _showSyncResultToast('Server unreachable. Scans remain queued.');
      setState(() {
        _isSyncing = false;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      _showSyncResultToast('Sync failed. Please try again.');
      setState(() {
        _isSyncing = false;
      });
      return;
    }

    if (!mounted) return;
    final remaining = widget.scansListenable.value
        .where((scan) => !scan.isSynced)
        .length;
    setState(() {
      _pendingCount = remaining;
      _isSyncing = false;
    });

    if (syncedCount > 0) {
      _showSyncResultToast('Sync complete. All scans uploaded.');
    } else if (_pendingCount > 0) {
      _showSyncResultToast('Server unreachable. Scans remain queued.');
    }
  }

  void _showSyncResultToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 1),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: darkGreen.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: caribbeanGreen.withValues(alpha: 0.4),
              width: 1,
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
                _pendingCount == 0
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                color: _pendingCount == 0
                    ? caribbeanGreen
                    : const Color(0xFFF59E0B),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showClearDataConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkGreen.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: caribbeanGreen.withValues(alpha: 0.4), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        title: const Text(
          'Clear Queued Scans?',
          style: TextStyle(color: antiFlashWhite, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This will permanently remove all offline pending scans from your device that haven\'t been synced to the server.',
          style: TextStyle(color: antiFlashWhite, fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: antiFlashWhite.withValues(alpha: 0.7)),
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.7)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Clear Data',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clearLocalScans();
    }
  }

  Future<void> _clearLocalScans() async {
    widget.onClearQueue?.call();

    if (mounted) {
      setState(() {
        _pendingCount = 0;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_tree_scans_v1');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: darkGreen,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: bangladeshGreen.withValues(alpha: 0.95),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: antiFlashWhite.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server & Sync Status',
                          style: TextStyle(
                            color: antiFlashWhite.withValues(alpha: 0.94),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          _isChecking
                              ? 'Checking connection...'
                              : _isConnected
                                  ? 'Connected to server'
                                  : 'Server unreachable',
                          style: TextStyle(
                            color: antiFlashWhite.withValues(alpha: 0.66),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: darkGreen.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: bangladeshGreen.withValues(alpha: 0.9),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dns_rounded,
                          size: 15,
                          color: caribbeanGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Target Endpoint',
                            style: TextStyle(
                              color: antiFlashWhite.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isConnected
                                ? caribbeanGreen.withValues(alpha: 0.18)
                                : const Color(0xFFEF4444).withValues(
                                    alpha: 0.18,
                                  ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _isConnected
                                  ? caribbeanGreen.withValues(alpha: 0.6)
                                  : const Color(0xFFEF4444).withValues(
                                      alpha: 0.6,
                                    ),
                            ),
                          ),
                          child: Text(
                            _isChecking
                                ? 'Checking...'
                                : _isConnected
                                    ? 'Connected'
                                    : 'Unreachable',
                            style: TextStyle(
                              color: _isConnected
                                  ? caribbeanGreen
                                  : const Color(0xFFEF4444),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _endpoint ?? '',
                      style: TextStyle(
                        color: antiFlashWhite.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: darkGreen.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: bangladeshGreen.withValues(alpha: 0.9),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync Queue',
                      style: TextStyle(
                        color: antiFlashWhite.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_pendingCount scans queued locally',
                      style: TextStyle(
                        color: antiFlashWhite.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Background auto-retry active on resume.',
                      style: TextStyle(
                        color: antiFlashWhite.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: caribbeanGreen,
                    foregroundColor: richBlack,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSyncing ? null : _syncPending,
                  child: _isSyncing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              richBlack,
                            ),
                          ),
                        )
                       : const Text(
                           'Sync Now',
                           style: TextStyle(fontWeight: FontWeight.w800),
                         ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pendingCount == 0
                      ? null
                      : () => _showClearDataConfirmation(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: _pendingCount == 0
                          ? Colors.white24
                          : Colors.redAccent.withValues(alpha: 0.6),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text(
                    'Clear Local Queue',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
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

class _TreeHighlightPainter extends CustomPainter {
  final List<Rect> rects;
  final Color color;

  const _TreeHighlightPainter({required this.rects, required this.color});

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
  bool shouldRepaint(covariant _TreeHighlightPainter oldDelegate) {
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

  const _DetectionBadge({required this.accent, required this.stabilityLabel});

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

  const _HighlightLegend({required this.showHighlights, required this.label});

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
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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
  final double? predictionConfidence;
  final StabilityAssessment? predictedAssessment;
  final String? capturedImagePath;
  final bool isSynced;

  const RecentTreeScan({
    required this.treeId,
    required this.scannedAt,
    required this.tree,
    this.predictionConfidence,
    this.predictedAssessment,
    this.capturedImagePath,
    this.isSynced = false,
  });

  StabilityAssessment get assessment =>
      predictedAssessment ?? StabilityAssessment.low;

  Map<String, dynamic> toJson() {
    return {
      'treeId': treeId,
      'scannedAt': scannedAt.toIso8601String(),
      if (predictionConfidence != null)
        'predictionConfidence': predictionConfidence,
      if (predictedAssessment != null)
        'predictedAssessment': predictedAssessment!.name,
      if (capturedImagePath != null) 'capturedImagePath': capturedImagePath,
      'isSynced': isSynced,
      'tree': {
        if (tree.treeBounds != null)
          'treeBounds': {
            'left': tree.treeBounds!.left,
            'top': tree.treeBounds!.top,
            'right': tree.treeBounds!.right,
            'bottom': tree.treeBounds!.bottom,
          },
      },
    };
  }

  factory RecentTreeScan.fromJson(Map<String, dynamic> json) {
    final treeMap = (json['tree'] as Map?)?.cast<String, dynamic>() ?? const {};

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
        if (assessment.name.toLowerCase() ==
            predictedAssessmentRaw.toLowerCase()) {
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
      predictionConfidence: (json['predictionConfidence'] as num?)?.toDouble(),
      predictedAssessment: predictedAssessment,
      capturedImagePath:
          ((json['capturedImagePath'] as String?)?.trim().isNotEmpty ?? false)
              ? (json['capturedImagePath'] as String).trim()
              : null,
      isSynced: (json['isSynced'] as bool?) ?? false,
      tree: MangroveTree(
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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF021B1A),
                  Color(0xFF032221),
                  Color(0xFF021B1A),
                ],
                stops: [0.0, 0.55, 1.0],
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