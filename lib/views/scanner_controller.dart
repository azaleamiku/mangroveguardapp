import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/mangrove_tree.dart';

enum ScanOutcome { detected, noMangroveDetected, captureOnly }

class MeasuredTreeResult {
  final MangroveTree tree;
  final double? predictionConfidence;
  final String? capturedImagePath;
  final ScanOutcome outcome;
  final StabilityAssessment? predictedAssessment;

  const MeasuredTreeResult({
    required this.tree,
    this.predictionConfidence,
    this.capturedImagePath,
    this.outcome = ScanOutcome.detected,
    this.predictedAssessment,
  });
}

class LiveFrameCache {
  final Uint8List imageBytes;
  final double? sharpnessScore;
  final double? framingScore;
  final StabilityAssessment? assessment;
  final double? confidence;
  final Rect? boundingBox;

  const LiveFrameCache({
    required this.imageBytes,
    this.sharpnessScore,
    this.framingScore,
    this.assessment,
    this.confidence,
    this.boundingBox,
  });
}

class ScannerPageController extends ChangeNotifier {
  int _shutterSignal = 0;
  MeasuredTreeResult? _latestMeasuredTreeResult;
  bool _isRealtimeAssessment = false;
  LiveFrameCache? _liveFrameCache;

  int get shutterSignal => _shutterSignal;
  bool get isRealtimeAssessment => _isRealtimeAssessment;

  void triggerShutter() {
    _shutterSignal++;
    notifyListeners();
  }

  void startRealtimeAssessment() {
    if (_isRealtimeAssessment) return;
    _isRealtimeAssessment = true;
    notifyListeners();
  }

  void stopRealtimeAssessment() {
    if (!_isRealtimeAssessment) return;
    _isRealtimeAssessment = false;
    notifyListeners();
  }

  void setLatestMeasuredTree({
    required MangroveTree tree,
    double? predictionConfidence,
    String? capturedImagePath,
    ScanOutcome outcome = ScanOutcome.detected,
    StabilityAssessment? predictedAssessment,
  }) {
    _latestMeasuredTreeResult = MeasuredTreeResult(
      tree: tree,
      predictionConfidence: predictionConfidence,
      capturedImagePath: capturedImagePath,
      outcome: outcome,
      predictedAssessment: predictedAssessment,
    );
  }

  MeasuredTreeResult? consumeLatestMeasuredTreeResult() {
    final result = _latestMeasuredTreeResult;
    _latestMeasuredTreeResult = null;
    return result;
  }

  void cacheLiveFrame(LiveFrameCache cache) {
    _liveFrameCache = cache;
    notifyListeners();
  }

  LiveFrameCache? consumeLiveFrameCache() {
    final cache = _liveFrameCache;
    _liveFrameCache = null;
    if (cache != null) notifyListeners();
    return cache;
  }

  void updateLiveFrameDetection({
    StabilityAssessment? assessment,
    double? confidence,
    Rect? boundingBox,
  }) {
    final existing = _liveFrameCache;
    if (existing == null) return;
    _liveFrameCache = LiveFrameCache(
      imageBytes: existing.imageBytes,
      sharpnessScore: existing.sharpnessScore,
      framingScore: existing.framingScore,
      assessment: assessment,
      confidence: confidence,
      boundingBox: boundingBox,
    );
    notifyListeners();
  }

  void clearLiveFrameCache() {
    if (_liveFrameCache == null) return;
    _liveFrameCache = null;
    notifyListeners();
  }

  void clearStaleLiveDetection() {
    _liveFrameCache = _liveFrameCache == null
        ? null
        : LiveFrameCache(
            imageBytes: _liveFrameCache!.imageBytes,
            sharpnessScore: _liveFrameCache!.sharpnessScore,
            framingScore: _liveFrameCache!.framingScore,
            assessment: null,
            confidence: _liveFrameCache!.confidence,
            boundingBox: null,
          );
    notifyListeners();
  }
}
