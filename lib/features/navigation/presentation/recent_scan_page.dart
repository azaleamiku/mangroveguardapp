import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../home/models/mangrove_tree.dart';

const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color bangladeshGreen = Color(0xFF03624C);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

String _stabilityLabel(StabilityAssessment assessment) {
  switch (assessment) {
    case StabilityAssessment.high:
      return 'High Stability';
    case StabilityAssessment.moderate:
      return 'Moderate Stability';
    case StabilityAssessment.low:
      return 'Low Stability';
  }
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
            final stabilityRatio = scan.stabilityIndex.clamp(0.0, 1.0);
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
                    child: DecoratedBox(
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
                                ? Image.file(
                                    File(imagePath!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
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
                  ),
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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final tileWidth =
                                (constraints.maxWidth - 12) / 2;
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: tileWidth,
                                  child: _MetricTile(
                                    label: 'Root Count',
                                    value: '${scan.rootCount}',
                                    accent: statusColor,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _MetricTile(
                                    label: 'Trunk Width',
                                    value:
                                        '${scan.trunkWidthCentimeters.toStringAsFixed(1)} cm',
                                    accent: statusColor,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _MetricTile(
                                    label: 'Root Spread',
                                    value:
                                        '${scan.rootSpreadCentimeters.toStringAsFixed(1)} cm',
                                    accent: statusColor,
                                  ),
                                ),
                                SizedBox(
                                  width: tileWidth,
                                  child: _MetricTile(
                                    label: 'Stability Index',
                                    value: scan.stabilityIndex
                                        .toStringAsFixed(2),
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
                                    color: const Color(0xFF86EFAC)
                                        .withValues(alpha: 0.34),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.24),
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
                                    color: const Color(0xFF5EEAD4)
                                        .withValues(alpha: 0.32),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF14B8A6)
                                          .withValues(alpha: 0.22),
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
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Stability Index = Root Spread / Trunk Width = '
                                          '${scan.rootSpreadMeters.toStringAsFixed(3)} m / '
                                          '${scan.trunkWidthMeters.toStringAsFixed(3)} m = '
                                          '${scan.stabilityIndex.toStringAsFixed(2)}',
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
                                            label: 'High (above 3.0)',
                                            active: scan.assessment ==
                                                StabilityAssessment.high,
                                            color: caribbeanGreen,
                                          ),
                                          _ThresholdChip(
                                            label: 'Moderate (1.5 to 3.0)',
                                            active: scan.assessment ==
                                                StabilityAssessment.moderate,
                                            color: const Color(0xFFF59E0B),
                                          ),
                                          _ThresholdChip(
                                            label: 'Low (below 1.5)',
                                            active: scan.assessment ==
                                                StabilityAssessment.low,
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        scan.assessment.description,
                                        style: TextStyle(
                                          color:
                                              antiFlashWhite.withValues(alpha: 0.76),
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
                              foregroundColor:
                                  antiFlashWhite.withValues(alpha: 0.84),
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

  const RecentTreeScan({
    required this.treeId,
    required this.scannedAt,
    required this.tree,
    this.metersPerPixel = 0.003,
    this.capturedImagePath,
  });

  int get rootCount => tree.roots.length;
  double get trunkWidthMeters => tree.trunkWidthPixels * metersPerPixel;
  double get rootSpreadMeters => tree.rootSpreadPixels * metersPerPixel;
  double get trunkWidthCentimeters => trunkWidthMeters * 100;
  double get rootSpreadCentimeters => rootSpreadMeters * 100;
  double get stabilityIndex => tree.stabilityIndex;
  StabilityAssessment get assessment => tree.assessment;

  Map<String, dynamic> toJson() {
    return {
      'treeId': treeId,
      'scannedAt': scannedAt.toIso8601String(),
      'metersPerPixel': metersPerPixel,
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

    final trunkMeasurementRaw =
        (treeMap['trunkMeasurement'] as Map?)?.cast<String, dynamic>();
    TrunkMeasurement? trunkMeasurement;
    if (trunkMeasurementRaw != null) {
      final startX = (trunkMeasurementRaw['startX'] as num?)?.toDouble();
      final endX = (trunkMeasurementRaw['endX'] as num?)?.toDouble();
      final y = (trunkMeasurementRaw['y'] as num?)?.toDouble();
      final isEstimated =
          (trunkMeasurementRaw['isEstimated'] as bool?) ?? true;
      if (startX != null && endX != null && y != null) {
        trunkMeasurement = TrunkMeasurement(
          startX: startX,
          endX: endX,
          y: y,
          isEstimated: isEstimated,
        );
      }
    }

    final treeBoundsRaw =
        (treeMap['treeBounds'] as Map?)?.cast<String, dynamic>();
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
        border: Border.all(
          color: bangladeshGreen.withValues(alpha: 0.9),
        ),
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
    final ratio = scan.stabilityIndex;

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
                    label: 'Trunk Width',
                    value:
                        '${scan.trunkWidthCentimeters.toStringAsFixed(1)} cm',
                  ),
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
                                      label: 'Trunk Width',
                                      value:
                                          '${scan.trunkWidthCentimeters.toStringAsFixed(1)} cm',
                                    ),
                                    const SizedBox(height: 6),
                                    _DetailRow(
                                      label: 'Root Spread',
                                      value:
                                          '${scan.rootSpreadCentimeters.toStringAsFixed(1)} cm',
                                    ),
                                    const SizedBox(height: 6),
                                    _DetailRow(
                                      label: 'Stability Index',
                                      value: ratio.toStringAsFixed(2),
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
                                  'Stability Index = Root Spread / Trunk Width = '
                                  '${scan.rootSpreadMeters.toStringAsFixed(3)} m / '
                                  '${scan.trunkWidthMeters.toStringAsFixed(3)} m = '
                                  '${ratio.toStringAsFixed(2)}',
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
                                    label: 'High (above 3.0)',
                                    active:
                                        scan.assessment ==
                                        StabilityAssessment.high,
                                    color: caribbeanGreen,
                                  ),
                                  _ThresholdChip(
                                    label: 'Moderate (1.5 to 3.0)',
                                    active:
                                        scan.assessment ==
                                        StabilityAssessment.moderate,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                  _ThresholdChip(
                                    label: 'Low (below 1.5)',
                                    active:
                                        scan.assessment ==
                                        StabilityAssessment.low,
                                    color: const Color(0xFFEF4444),
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
  final Color accent;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: richBlack.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: antiFlashWhite.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: antiFlashWhite,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
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
