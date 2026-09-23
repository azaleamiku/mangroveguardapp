import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mangroveguardapp/models/mangrove_tree.dart';
import 'package:mangroveguardapp/services/mangrove_detector.dart';

const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

const String _liveIsolateReady = 'ready';
const String _liveIsolateProcess = 'process';
const String _liveIsolateResult = 'result';
const String _liveIsolateError = 'error';
const String _liveIsolateStop = 'stop';

ImageFormatGroup? resolveCameraFormatGroup({required bool isAndroid}) {
  if (isAndroid) {
    return null;
  }
  return ImageFormatGroup.bgra8888;
}

int _clampByte(num value) {
  if (value < 0) return 0;
  if (value > 255) return 255;
  return value.round();
}

img.Image _convertYuv420ToRgb({
  required int width,
  required int height,
  required Uint8List bytesY,
  required Uint8List bytesU,
  required Uint8List bytesV,
  required int yRowStride,
  required int uvRowStride,
  required int uvPixelStride,
  int? maxDimension,
}) {
  final scale = (maxDimension == null)
      ? 1
      : math.max(
          1,
          ((math.max(width, height) + maxDimension - 1) ~/ maxDimension),
        );
  final scaledWidth = (width + scale - 1) ~/ scale;
  final scaledHeight = (height + scale - 1) ~/ scale;
  final img.Image imgImage = img.Image(
    width: scaledWidth,
    height: scaledHeight,
  );

  var dy = 0;
  for (int y = 0; y < height; y += scale) {
    final int uvRow = uvRowStride * (y >> 1);
    final int yRow = yRowStride * y;
    var dx = 0;
    for (int x = 0; x < width; x += scale) {
      final int yIndex = yRow + x;
      final int uvIndex = uvRow + (x >> 1) * uvPixelStride;
      final int yVal = bytesY[yIndex];
      final int uVal = bytesU[uvIndex];
      final int vVal = bytesV[uvIndex];
      final int r = _clampByte(yVal + (1.403 * (vVal - 128)));
      final int g = _clampByte(
        yVal - (0.344 * (uVal - 128)) - (0.714 * (vVal - 128)),
      );
      final int b = _clampByte(yVal + (1.770 * (uVal - 128)));
      imgImage.setPixelRgb(dx, dy, r, g, b);
      dx++;
    }
    dy++;
  }

  if (scaledWidth > scaledHeight) {
    return img.copyRotate(imgImage, angle: 90);
  }
  return imgImage;
}

Rect? _cropRectFromNormalized({
  required double left,
  required double top,
  required double right,
  required double bottom,
  required int width,
  required int height,
}) {
  final cropLeft = (left * width).round().clamp(0, width - 1);
  final cropTop = (top * height).round().clamp(0, height - 1);
  final cropRight = (right * width).round().clamp(cropLeft + 1, width);
  final cropBottom = (bottom * height).round().clamp(cropTop + 1, height);
  if (cropRight - cropLeft <= 1 || cropBottom - cropTop <= 1) {
    return null;
  }
  return Rect.fromLTRB(
    cropLeft.toDouble(),
    cropTop.toDouble(),
    cropRight.toDouble(),
    cropBottom.toDouble(),
  );
}

void _liveAssessmentIsolate(Map<String, Object?> config) async {
  final sendPort = config['sendPort'] as SendPort;
  final modelData = config['modelData'] as TransferableTypedData;
  final modelBytes = modelData.materialize().asUint8List();

  MangroveDetector detector;
  try {
    detector = await MangroveDetector.createFromBuffer(modelBytes);
  } catch (e) {
    sendPort.send({'type': _liveIsolateError, 'error': e.toString()});
    return;
  }

  final receivePort = ReceivePort();
  sendPort.send({'type': _liveIsolateReady, 'sendPort': receivePort.sendPort});

  await for (final message in receivePort) {
    if (message is! Map<String, Object?>) continue;
    final type = message['type'];
    if (type == _liveIsolateStop) {
      break;
    }
    if (type != _liveIsolateProcess) continue;

    final requestId = message['requestId'] as int?;
    try {
      final width = message['width'] as int;
      final height = message['height'] as int;
      final yRowStride = message['yRowStride'] as int;
      final uvRowStride = message['uvRowStride'] as int;
      final uvPixelStride = message['uvPixelStride'] as int;
      final maxDimension = message['maxDimension'] as int?;
      final bytesY = (message['bytesY'] as TransferableTypedData)
          .materialize()
          .asUint8List();
      final bytesU = (message['bytesU'] as TransferableTypedData)
          .materialize()
          .asUint8List();
      final bytesV = (message['bytesV'] as TransferableTypedData)
          .materialize()
          .asUint8List();
      final crop = message['crop'] as Map<String, Object?>?;

      var rgb = _convertYuv420ToRgb(
        width: width,
        height: height,
        bytesY: bytesY,
        bytesU: bytesU,
        bytesV: bytesV,
        yRowStride: yRowStride,
        uvRowStride: uvRowStride,
        uvPixelStride: uvPixelStride,
        maxDimension: maxDimension,
      );

      if (crop != null) {
        final rect = _cropRectFromNormalized(
          left: (crop['left'] as num).toDouble(),
          top: (crop['top'] as num).toDouble(),
          right: (crop['right'] as num).toDouble(),
          bottom: (crop['bottom'] as num).toDouble(),
          width: rgb.width,
          height: rgb.height,
        );
        if (rect != null) {
          rgb = img.copyCrop(
            rgb,
            x: rect.left.round(),
            y: rect.top.round(),
            width: rect.width.round(),
            height: rect.height.round(),
          );
        }
      }

      final detection = await detector.detectFromImage(rgb);
      sendPort.send({
        'type': _liveIsolateResult,
        'requestId': requestId,
        'assessment': detection.predictedAssessment?.name,
        'confidence': detection.predictionConfidence,
        'boundingBox': detection.boundingBox != null
            ? {
                'left': detection.boundingBox!.left,
                'top': detection.boundingBox!.top,
                'right': detection.boundingBox!.right,
                'bottom': detection.boundingBox!.bottom,
              }
            : null,
      });
    } catch (e) {
      sendPort.send({
        'type': _liveIsolateError,
        'requestId': requestId,
        'error': e.toString(),
      });
    }
  }

  detector.dispose();
  receivePort.close();
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

enum ScanOutcome { detected, noMangroveDetected, captureOnly }

class ScannerPage extends StatefulWidget {
  final ScannerPageController? controller;
  final VoidCallback? onScanCompleted;
  final bool isActive;

  const ScannerPage({
    super.key,
    this.controller,
    this.onScanCompleted,
    this.isActive = true,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  static const double _minPredictionConfidence = 0.25;
  static const Duration _realtimeInterval = Duration(milliseconds: 380);
  static const int _liveProcessingMaxDimension = 768;
  static const double _liveBoundingBoxSmoothing = 0.35;
  static const double _sharpnessLowVariance = 80;
  static const double _sharpnessHighVariance = 280;
  static const double _framingLowEdge = 6;
  static const double _framingHighEdge = 20;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraInitInFlight = false;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isPermissionDenied = false;
  bool _isPermanentlyDenied = false;
  bool _isCheckingPermission = false;
  String? _cameraError;
  MangroveDetector? _detector;
  Future<MangroveDetector?>? _detectorFuture;
  bool _isDetectorReady = false;
  String? _detectorError;
  final ImagePicker _imagePicker = ImagePicker();
  int _lastShutterSignal = 0;
  bool _lastRealtimeSignal = false;
  final GlobalKey _frameGuideInnerKey = GlobalKey();
  Rect? _lastFrameRectInViewport;
  Size? _lastViewportSize;
  bool _isRealtimeAssessment = false;
  bool _isRealtimeProcessing = false;
  DateTime _lastRealtimeRun = DateTime.fromMillisecondsSinceEpoch(0);
  StabilityAssessment? _liveAssessment;
  double? _liveConfidence;
  double? _liveSharpnessScore;
  double? _liveFramingScore;
  Rect? _liveBoundingBox;
  Rect? _smoothedBoundingBox;
  Isolate? _liveIsolate;
  ReceivePort? _liveReceivePort;
  SendPort? _liveSendPort;
  bool _isLiveIsolateReady = false;
  bool _isLiveIsolateStarting = false;
  Completer<void>? _liveReadyCompleter;
  int _liveRequestId = 0;
  int _pendingLiveRequestId = 0;
  Uint8List? _liveModelBytes;
  Timer? _liveStaleTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?.addListener(_handleControllerSignal);
    _lastShutterSignal = widget.controller?.shutterSignal ?? 0;
    _lastRealtimeSignal = widget.controller?.isRealtimeAssessment ?? false;
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scheduleCameraInit(),
      );
    }
    _initDetector();
    unawaited(_ensureLiveIsolateReady());
  }

  @override
  void didUpdateWidget(covariant ScannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerSignal);
      widget.controller?.addListener(_handleControllerSignal);
      _lastShutterSignal = widget.controller?.shutterSignal ?? 0;
      _lastRealtimeSignal = widget.controller?.isRealtimeAssessment ?? false;
    }

    if (widget.isActive && !oldWidget.isActive) {
      _resetPermissionState();
      _resumeCameraForTabSwitch();
    } else if (!widget.isActive && oldWidget.isActive) {
      _pauseCameraForTabSwitch();
    }
  }

  @override
  void dispose() {
    widget.controller?.stopRealtimeAssessment();
    widget.controller?.removeListener(_handleControllerSignal);
    WidgetsBinding.instance.removeObserver(this);
    _stopRealtimeAssessment();
    _disposeLiveIsolate();
    unawaited(_disposeCameraController());
    _detector?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isPermissionDenied) {
        unawaited(_recheckDeniedPermission());
      } else {
        _scheduleCameraInit();
      }
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.controller?.stopRealtimeAssessment();
      _stopRealtimeAssessment();
      _disposeLiveIsolate();
      unawaited(_disposeCameraController());
      _cameraController = null;
    }
  }

  Future<void> _recheckDeniedPermission() async {
    if (!mounted || _isCheckingPermission) return;
    _isCheckingPermission = true;

    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        _resetPermissionState();
        await _initCamera();
      }
    } catch (_) {
      debugPrint('Permission recheck failed:');
    } finally {
      _isCheckingPermission = false;
    }
  }

  void _scheduleCameraInit() {
    if (!mounted) return;
    if (!widget.isActive) return;
    if (_isPermissionDenied) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      return;
    }
    unawaited(_ensureLiveIsolateReady());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      if (_isPermissionDenied) return;
      final controller = _cameraController;
      if (controller != null && controller.value.isInitialized) {
        unawaited(_resumeCameraForTabSwitch());
      } else {
        unawaited(_initCamera());
      }
    });
  }

  void _resetPermissionState() {
    _isPermissionDenied = false;
    _isPermanentlyDenied = false;
    _isCheckingPermission = false;
  }

  Future<void> _initCamera() async {
    if (!mounted || _cameraInitInFlight || _isCheckingPermission) return;
    if (_isPermissionDenied) return;
    _cameraInitInFlight = true;
    _isCheckingPermission = true;
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        _resetPermissionState();
      } else if (status.isPermanentlyDenied) {
        _isPermissionDenied = true;
        _isPermanentlyDenied = true;
        if (!mounted) return;
        setState(() {
          _cameraError =
              'Camera permission is permanently denied. Please enable camera access in app settings.';
          _isInitializing = false;
        });
        return;
      }

      final granted = await Permission.camera.request();
      if (granted.isGranted) {
        _resetPermissionState();
      } else if (granted.isPermanentlyDenied) {
        _isPermissionDenied = true;
        _isPermanentlyDenied = true;
        if (!mounted) return;
        setState(() {
          _cameraError =
              'Camera permission is permanently denied. Please enable camera access in app settings.';
          _isInitializing = false;
        });
        return;
      } else {
        _isPermissionDenied = true;
        _isPermanentlyDenied = false;
        if (!mounted) return;
        setState(() {
          _cameraError = 'Camera permission is required to scan mangroves.';
          _isInitializing = false;
        });
        return;
      }

      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraError = 'No camera available on this device.';
          _isInitializing = false;
        });
        return;
      }

      final selectedCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        selectedCamera,

        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: resolveCameraFormatGroup(
          isAndroid: Platform.isAndroid,
        ),
      );

      try {
        await controller.initialize();
      } on CameraException catch (e) {
        if (!mounted) return;
        setState(() {
          _cameraError =
              'Camera error: ${e.description ?? e.code}';
          _isInitializing = false;
        });
        return;
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      final currentLifecycle = WidgetsBinding.instance.lifecycleState;
      if (currentLifecycle == AppLifecycleState.paused ||
          currentLifecycle == AppLifecycleState.detached) {
        await controller.dispose();
        return;
      }

      await _disposeCameraController();
      _cameraController = controller;
      setState(() {
        _isInitializing = false;
        _cameraError = null;
      });

      unawaited(_configureCameraForFastCapture(controller));

      if (_lastRealtimeSignal) {
        unawaited(_startRealtimeAssessment());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Unable to initialize camera.';
        _isInitializing = false;
      });
    } finally {
      _cameraInitInFlight = false;
      _isCheckingPermission = false;
    }
  }

  Future<void> _initDetector() async {
    setState(() {
      _isDetectorReady = false;
      _detectorError = null;
    });
    final future = _createDetector();
    _detectorFuture = future;
    final detector = await future;
    if (!mounted) return;
    setState(() {
      _isDetectorReady = detector != null;
      _detectorError ??= detector == null ? 'Model failed to load.' : null;
    });
  }

  Future<MangroveDetector?> _createDetector() async {
    try {
      final detector = await MangroveDetector.create();
      if (!mounted) {
        detector.dispose();
        return null;
      }
      _detector = detector;
      return detector;
    } catch (e) {
      debugPrint('Detector initialization failed: $e');
      if (mounted) {
        _detectorError = 'Model failed to load.';
      }
      return null;
    }
  }

  Future<MangroveDetector?> _ensureDetector() async {
    final existing = _detector;
    if (existing != null) return existing;
    final future = _detectorFuture;
    if (future == null) return null;
    return future;
  }

  Future<void> _ensureLiveIsolateReady() async {
    if (_isLiveIsolateReady) return;
    if (_isLiveIsolateStarting) {
      final completer = _liveReadyCompleter;
      if (completer != null) {
        await completer.future;
      }
      return;
    }

    _isLiveIsolateStarting = true;
    _liveReadyCompleter = Completer<void>();

    try {
      _liveModelBytes ??= await MangroveDetector.loadModelBytes();
      _liveReceivePort ??= ReceivePort();
      _liveReceivePort!.listen(_handleLiveIsolateMessage);
      _liveIsolate = await Isolate.spawn(_liveAssessmentIsolate, {
        'sendPort': _liveReceivePort!.sendPort,
        'modelData': TransferableTypedData.fromList([_liveModelBytes!]),
      }, debugName: 'live-assessment');
      await _liveReadyCompleter!.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          final completer = _liveReadyCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
        },
      );
    } catch (e) {
      debugPrint('Failed to start live assessment isolate: $e');
      final completer = _liveReadyCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    } finally {
      _isLiveIsolateStarting = false;
    }
  }

  Future<void> _disposeCameraController() async {
    final controller = _cameraController;
    if (controller == null) return;
    _cameraController = null;
    try {
      await controller.dispose();
    } catch (e) {
      debugPrint('Failed to dispose camera controller cleanly: $e');
    }
  }

  void _clearStaleLiveAssessment() {
    if (!_isRealtimeAssessment) return;
    _liveStaleTimer = null;
    if (mounted) {
      setState(() {
        _liveAssessment = null;
        _liveBoundingBox = null;
      });
    } else {
      _liveAssessment = null;
      _liveBoundingBox = null;
    }
    widget.controller?.clearStaleLiveDetection();
  }

  void _disposeLiveIsolate() {
    _isLiveIsolateReady = false;
    _isLiveIsolateStarting = false;
    _liveStaleTimer?.cancel();
    _liveStaleTimer = null;
    final completer = _liveReadyCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _liveReadyCompleter = null;
    try {
      _liveSendPort?.send({'type': _liveIsolateStop});
    } catch (_) {}
    _liveReceivePort?.close();
    _liveReceivePort = null;
    _liveSendPort = null;
    final isolate = _liveIsolate;
    _liveIsolate = null;
    if (isolate != null) {
      try {
        isolate.kill(priority: Isolate.immediate);
      } catch (_) {}
    }
  }

  void _handleLiveIsolateMessage(dynamic message) {
    if (message is! Map) return;
    final type = message['type'];
    if (type == _liveIsolateReady) {
      _liveSendPort = message['sendPort'] as SendPort?;
      _isLiveIsolateReady = _liveSendPort != null;
      final completer = _liveReadyCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      return;
    }

    if (type == _liveIsolateResult) {
      final requestId = message['requestId'] as int?;
      if (requestId == null || requestId != _pendingLiveRequestId) {
        return;
      }
      if (!_isRealtimeAssessment) {
        _isRealtimeProcessing = false;
        return;
      }
      final assessmentName = message['assessment'] as String?;
      final confidence = message['confidence'] as double?;

      final bool isConfident =
          confidence != null && confidence >= _minPredictionConfidence;
      StabilityAssessment? assessment;
      if (assessmentName != null && isConfident) {
        try {
          assessment = StabilityAssessment.values.byName(assessmentName);
        } on StateError {
          assessment = null;
        }
      }

      final bboxMap = message['boundingBox'] as Map<Object?, Object?>?;
      Rect? boundingBox;
      if (bboxMap != null && isConfident) {
        boundingBox = Rect.fromLTRB(
          (bboxMap['left'] as num).toDouble(),
          (bboxMap['top'] as num).toDouble(),
          (bboxMap['right'] as num).toDouble(),
          (bboxMap['bottom'] as num).toDouble(),
        );
      }

      if (mounted) {
        setState(() {
          _liveConfidence = confidence;
          if (isConfident) {
            _liveAssessment = assessment;
            if (boundingBox != null) {
              _smoothedBoundingBox ??= boundingBox;
              _smoothedBoundingBox = Rect.fromLTRB(
                _liveBoundingBoxSmoothing * boundingBox.left +
                    (1 - _liveBoundingBoxSmoothing) * _smoothedBoundingBox!.left,
                _liveBoundingBoxSmoothing * boundingBox.top +
                    (1 - _liveBoundingBoxSmoothing) * _smoothedBoundingBox!.top,
                _liveBoundingBoxSmoothing * boundingBox.right +
                    (1 - _liveBoundingBoxSmoothing) * _smoothedBoundingBox!.right,
                _liveBoundingBoxSmoothing * boundingBox.bottom +
                    (1 - _liveBoundingBoxSmoothing) * _smoothedBoundingBox!.bottom,
              );
              _liveBoundingBox = _smoothedBoundingBox;
            }
          }
        });
      } else {
        _liveConfidence = confidence;
        if (isConfident) {
          _liveAssessment = assessment;
          if (boundingBox != null) {
            _smoothedBoundingBox ??= boundingBox;
            _smoothedBoundingBox = Rect.fromLTRB(
              _liveBoundingBoxSmoothing * boundingBox.left +
                  (1 - _liveBoundingBoxSmoothing) * _smoothedBoundingBox!.left,
              _liveBoundingBoxSmoothing * boundingBox.top +
                  (1 - _liveBoundingBoxSmoothing) * _smoothedBoundingBox!.top,
              _liveBoundingBoxSmoothing * boundingBox.right +
                  (1 - _liveBoundingBoxSmoothing) * _smoothedBoundingBox!.right,
              _liveBoundingBoxSmoothing * boundingBox.bottom +
                  (1 - _liveBoundingBoxSmoothing) * _smoothedBoundingBox!.bottom,
            );
            _liveBoundingBox = _smoothedBoundingBox;
          }
        }
      }
      widget.controller?.updateLiveFrameDetection(
        assessment: _liveAssessment,
        confidence: confidence,
        boundingBox: _liveBoundingBox,
      );
      _isRealtimeProcessing = false;
      if (isConfident) {
        _liveStaleTimer?.cancel();
        _liveStaleTimer = Timer(const Duration(seconds: 2), _clearStaleLiveAssessment);
      }
      return;
    }

    if (type == _liveIsolateError) {
      _isRealtimeProcessing = false;
      final completer = _liveReadyCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      debugPrint('Live assessment isolate error: ${message['error']}');
    }
  }

  void _handleControllerSignal() {
    final controller = widget.controller;
    if (controller == null) return;

    if (controller.shutterSignal != _lastShutterSignal) {
      _lastShutterSignal = controller.shutterSignal;
      _captureShutter();
    }

    if (controller.isRealtimeAssessment != _lastRealtimeSignal) {
      _lastRealtimeSignal = controller.isRealtimeAssessment;
      if (_lastRealtimeSignal) {
        unawaited(_startRealtimeAssessment());
      } else {
        _stopRealtimeAssessment();
      }
    }
  }

  void _resetPermissionStateAndRetry() {
    _resetPermissionState();
    unawaited(_initCamera());
  }

  Future<void> _pauseCameraForTabSwitch() async {
    _stopRealtimeAssessment();
    _disposeLiveIsolate();
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
    }
    _cameraInitInFlight = false;
    if (mounted) {
      setState(() {
        _isInitializing = false;
        _cameraError = null;
      });
    }
  }

  Future<void> _resumeCameraForTabSwitch() async {
    if (!mounted) return;
    if (_isPermissionDenied) return;
    
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        if (!controller.value.isStreamingImages) {
          await controller.startImageStream(_handleCameraImage);
        }
      } catch (_) {}
      
      if (_lastRealtimeSignal) {
        unawaited(_startRealtimeAssessment());
      }
      
      setState(() {
        _isInitializing = false;
        _cameraError = null;
      });
    } else {
      _scheduleCameraInit();
    }
  }

  Future<void> _configureCameraForFastCapture(
    CameraController controller,
  ) async {
    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {}
    try {
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {}
    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}
  }

  void _storeCapturedImageResult(String imagePath) {
    widget.controller?.setLatestMeasuredTree(
      tree: const MangroveTree(),
      capturedImagePath: imagePath,
      outcome: ScanOutcome.captureOnly,
    );
  }

  Future<ScanOutcome> _storeDetectedImageResult(String imagePath) async {
    final detector = await _ensureDetector();
    if (detector == null) {
      _storeCapturedImageResult(imagePath);
      return ScanOutcome.captureOnly;
    }

    try {
      final detection = await detector.detect(imagePath);
      final confidence = detection.predictionConfidence;
      final isConfident =
          confidence != null && confidence >= _minPredictionConfidence;
      final predictedAssessment = detection.predictedAssessment;
      widget.controller?.setLatestMeasuredTree(
        tree: detection.tree,
        predictionConfidence: confidence,
        capturedImagePath: imagePath,
        outcome: predictedAssessment != null && isConfident
            ? ScanOutcome.detected
            : ScanOutcome.noMangroveDetected,
        predictedAssessment: predictedAssessment,
      );
      return predictedAssessment != null && isConfident
          ? ScanOutcome.detected
          : ScanOutcome.noMangroveDetected;
    } catch (e) {
      debugPrint('Detector failed: $e');
      _storeCapturedImageResult(imagePath);
      if (!mounted) return ScanOutcome.captureOnly;
      _showTopNotification('Detection failed. Saved photo only.');
      return ScanOutcome.captureOnly;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cacheFrameRectIfPossible();
    });

    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: richBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: caribbeanGreen),
              SizedBox(height: 20),
              Text(
                'Initializing Scanner...',
                style: TextStyle(color: antiFlashWhite, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_isPermissionDenied) {
      return Scaffold(
        backgroundColor: richBlack,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off,
                  color: Colors.redAccent,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  _cameraError ??
                      'Camera permission is required to scan mangroves.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: antiFlashWhite, fontSize: 15),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isPermanentlyDenied
                          ? () => openAppSettings()
                          : _resetPermissionStateAndRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: caribbeanGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _isPermanentlyDenied ? 'Open Settings' : 'Retry',
                        style: const TextStyle(
                          color: richBlack,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_cameraError != null) {
      final isPermanentlyDenied =
          _cameraError!.contains('permanently denied') ||
          _cameraError!.contains('app settings');
      return Scaffold(
        backgroundColor: richBlack,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off,
                  color: Colors.redAccent,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: antiFlashWhite, fontSize: 15),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _initCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: caribbeanGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: richBlack,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isPermanentlyDenied)
                      OutlinedButton(
                        onPressed: () => openAppSettings(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: antiFlashWhite,
                          side: const BorderSide(color: caribbeanGreen),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Open Settings'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: richBlack,
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraPreview()),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.58),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.66),
                    ],
                    stops: const [0, 0.42, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _isCapturing ? 1 : 0,
                child: Container(color: Colors.white.withValues(alpha: 0.14)),
              ),
            ),
          ),
          _buildScannerHud(),
          if (_isRealtimeAssessment) _buildBoundingBoxOverlay(),
        ],
      ),
    );
  }

  Widget _buildScannerHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatusChip(
                  icon: _isCapturing
                      ? Icons.camera
                      : (_isRealtimeAssessment
                            ? Icons.sensors
                            : Icons.check_circle),
                  label: _isRealtimeAssessment ? 'Assessing' : 'Ready',
                  glow: _isCapturing
                      ? const Color(0xFFFFA34D)
                      : (_isRealtimeAssessment
                            ? const Color(0xFF56E0D4)
                            : caribbeanGreen),
                  trailing: (_isCapturing || _isRealtimeAssessment)
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              antiFlashWhite,
                            ),
                          ),
                        )
                      : null,
                ),
                const Spacer(),
                _buildStatusChip(
                  icon: _detectorError != null
                      ? Icons.error_outline
                      : (_isDetectorReady ? Icons.memory : Icons.hourglass_top),
                  label: _detectorError != null
                      ? 'Model Error'
                      : (_isDetectorReady ? 'Model Ready' : 'Model Loading'),
                  glow: _detectorError != null
                      ? Colors.redAccent
                      : (_isDetectorReady
                            ? caribbeanGreen
                            : const Color(0xFFFFA34D)),
                  trailing: (!_isDetectorReady && _detectorError == null)
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              antiFlashWhite,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 0.85,
                  child: Container(
                    key: _frameGuideInnerKey,
                    decoration: !_isRealtimeAssessment
                        ? BoxDecoration(
                            border: Border.all(
                              color: caribbeanGreen.withValues(alpha: 0.22),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildGuidancePanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color glow,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: darkGreen.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: glow.withValues(alpha: 0.48)),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.24),
            blurRadius: 12,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: antiFlashWhite),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: antiFlashWhite,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ],
      ),
    );
  }

  Widget _buildGuidancePanel() {
    final canUpload = !_isCapturing && !_isRealtimeAssessment;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: darkGreen.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: caribbeanGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isRealtimeAssessment ? 'Live Assessment' : 'Field Guidance',
            style: const TextStyle(
              color: antiFlashWhite,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          if (_isRealtimeAssessment) ...[
            Text(
              _liveAssessment != null
                  ? '${_liveAssessment!.name.toUpperCase()} STABILITY DETECTED'
                  : (_isDetectorReady
                        ? 'SCANNING FOR MANGROVES...'
                        : 'MODEL LOADING...'),
              style: TextStyle(
                color: _liveAssessment == StabilityAssessment.high
                    ? caribbeanGreen
                    : _liveAssessment == StabilityAssessment.moderate
                    ? const Color(0xFFFFA34D)
                    : _liveAssessment == StabilityAssessment.low
                    ? Colors.redAccent
                    : antiFlashWhite.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                String description;
                switch (_liveAssessment) {
                  case StabilityAssessment.high:
                    description =
                        "This mangrove shows High Stability. It acts as a primary defense line, capable of absorbing heavy wave energy and resisting gale-force winds. Its deep, interlocking root system makes it highly unlikely to uproot during a storm.";
                    break;
                  case StabilityAssessment.moderate:
                    description =
                        "This mangrove shows Moderate Stability. While it offers decent protection, it may suffer branch breakage or partial root loosening during a strong storm. It can handle moderate winds, but it needs surrounding support to stay upright in a typhoon.";
                    break;
                  case StabilityAssessment.low:
                    description =
                        "This mangrove has Low Stability. It provides minimal protection against storm surges and is at high risk of being uprooted by strong winds. In its current state, it may not survive a major weather event and could even become floating debris.";
                    break;
                  default:
                    description = _isDetectorReady
                        ? 'Scanning for mangroves...'
                        : 'Model Loading...';
                }
                return Text(
                  description,
                  style: const TextStyle(
                    color: antiFlashWhite,
                    fontSize: 12,
                    height: 1.4,
                  ),
                );
              },
            ),
          ] else ...[
            const Text(
              '1) Position the tree within the frame, capturing from the roots up to the visible trunk.\n2) Keep steady and tap or hold the shutter button.\n3) Re-capture if any part of the tree (roots or trunk) is cut off.',
              style: TextStyle(
                color: antiFlashWhite,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Hold the shutter to start live assessment. Hold again to stop.',
              style: TextStyle(
                color: antiFlashWhite,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
          if (!_isRealtimeAssessment) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: canUpload ? _handleUploadPhoto : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: antiFlashWhite,
                  backgroundColor: darkGreen.withValues(alpha: 0.45),
                  side: BorderSide(
                    color: caribbeanGreen.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('Upload Photo'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBoundingBoxOverlay() {
    final bbox = _liveBoundingBox;
    final frameRect = _lastFrameRectInViewport;
    if (bbox == null || frameRect == null) return const SizedBox.shrink();

    final left = frameRect.left + bbox.left * frameRect.width;
    final top = frameRect.top + bbox.top * frameRect.height;
    final width = bbox.width * frameRect.width;
    final height = bbox.height * frameRect.height;

    Color boxColor;
    switch (_liveAssessment) {
      case StabilityAssessment.high:
        boxColor = caribbeanGreen;
        break;
      case StabilityAssessment.moderate:
        boxColor = const Color(0xFFFFA34D);
        break;
      case StabilityAssessment.low:
        boxColor = Colors.redAccent;
        break;
      default:
        boxColor = caribbeanGreen;
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: boxColor, width: 2.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: boxColor.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  void _cacheFrameRectIfPossible() {
    final frameContext = _frameGuideInnerKey.currentContext;
    final rootRenderObject = context.findRenderObject();
    final frameRenderObject = frameContext?.findRenderObject();
    if (rootRenderObject is! RenderBox || frameRenderObject is! RenderBox) {
      return;
    }

    final frameGlobalTopLeft = frameRenderObject.localToGlobal(Offset.zero);
    final rootGlobalTopLeft = rootRenderObject.localToGlobal(Offset.zero);
    _lastFrameRectInViewport =
        (frameGlobalTopLeft - rootGlobalTopLeft) & frameRenderObject.size;
    _lastViewportSize = rootRenderObject.size;
  }

  Rect? _previewCropRectForFrameGuide({
    required double previewWidth,
    required double previewHeight,
  }) {
    _cacheFrameRectIfPossible();
    final frameRectInViewport = _lastFrameRectInViewport;
    final viewportSize = _lastViewportSize;
    if (frameRectInViewport == null || viewportSize == null) return null;
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return null;
    if (previewWidth <= 0 || previewHeight <= 0) return null;

    final scale = math.max(
      viewportSize.width / previewWidth,
      viewportSize.height / previewHeight,
    );
    final displayedWidth = previewWidth * scale;
    final displayedHeight = previewHeight * scale;
    final offsetX = (viewportSize.width - displayedWidth) / 2;
    final offsetY = (viewportSize.height - displayedHeight) / 2;

    final previewCropRect = Rect.fromLTRB(
      ((frameRectInViewport.left - offsetX) / scale).clamp(0.0, previewWidth),
      ((frameRectInViewport.top - offsetY) / scale).clamp(0.0, previewHeight),
      ((frameRectInViewport.right - offsetX) / scale).clamp(0.0, previewWidth),
      ((frameRectInViewport.bottom - offsetY) / scale).clamp(
        0.0,
        previewHeight,
      ),
    );
    if (previewCropRect.width <= 1 || previewCropRect.height <= 1) {
      return null;
    }
    return previewCropRect;
  }

  Rect? _normalizedCropRectForFrameGuide({
    required double previewWidth,
    required double previewHeight,
  }) {
    var normalizedWidth = previewWidth;
    var normalizedHeight = previewHeight;
    if (previewWidth > previewHeight) {
      normalizedWidth = previewHeight;
      normalizedHeight = previewWidth;
    }
    final rect = _previewCropRectForFrameGuide(
      previewWidth: normalizedWidth,
      previewHeight: normalizedHeight,
    );
    if (rect == null || normalizedWidth == 0 || normalizedHeight == 0) {
      return null;
    }
    return Rect.fromLTRB(
      rect.left / normalizedWidth,
      rect.top / normalizedHeight,
      rect.right / normalizedWidth,
      rect.bottom / normalizedHeight,
    );
  }

  void _updateQualityMetrics(CameraImage image, Rect? normalizedCrop) {
    if (!_isRealtimeAssessment) return;
    if (image.planes.isEmpty) return;
    final yPlane = image.planes[0];
    final variance = _computeLaplacianVariance(
      bytes: yPlane.bytes,
      width: image.width,
      height: image.height,
      rowStride: yPlane.bytesPerRow,
      normalizedCrop: normalizedCrop,
    );
    final edgeMean = _computeEdgeMean(
      bytes: yPlane.bytes,
      width: image.width,
      height: image.height,
      rowStride: yPlane.bytesPerRow,
      normalizedCrop: normalizedCrop,
    );
    final sharpnessScore = _scoreFromRange(
      variance,
      _sharpnessLowVariance,
      _sharpnessHighVariance,
    );
    final framingScore = _scoreFromRange(
      edgeMean,
      _framingLowEdge,
      _framingHighEdge,
    );

    if (mounted) {
      setState(() {
        _liveSharpnessScore = sharpnessScore;
        _liveFramingScore = framingScore;
      });
    } else {
      _liveSharpnessScore = sharpnessScore;
      _liveFramingScore = framingScore;
    }
  }

  double _scoreFromRange(double value, double low, double high) {
    if (high <= low) return 0;
    return ((value - low) / (high - low)).clamp(0.0, 1.0);
  }

  double _computeLaplacianVariance({
    required Uint8List bytes,
    required int width,
    required int height,
    required int rowStride,
    Rect? normalizedCrop,
    int step = 4,
  }) {
    if (width < 3 || height < 3) return 0;
    var left = 1;
    var top = 1;
    var right = width - 2;
    var bottom = height - 2;

    if (normalizedCrop != null) {
      left = (normalizedCrop.left * width).round().clamp(1, width - 2);
      top = (normalizedCrop.top * height).round().clamp(1, height - 2);
      right = (normalizedCrop.right * width).round().clamp(1, width - 2);
      bottom = (normalizedCrop.bottom * height).round().clamp(1, height - 2);
    }

    if (right <= left || bottom <= top) return 0;

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = top; y <= bottom; y += step) {
      final row = y * rowStride;
      for (int x = left; x <= right; x += step) {
        final idx = row + x;
        final center = bytes[idx];
        final laplacian =
            bytes[idx - 1] +
            bytes[idx + 1] +
            bytes[idx - rowStride] +
            bytes[idx + rowStride] -
            (4 * center);
        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }

    if (count == 0) return 0;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return variance.isFinite ? variance : 0;
  }

  double _computeEdgeMean({
    required Uint8List bytes,
    required int width,
    required int height,
    required int rowStride,
    Rect? normalizedCrop,
    int step = 4,
  }) {
    if (width < 3 || height < 3) return 0;
    var left = 1;
    var top = 1;
    var right = width - 2;
    var bottom = height - 2;

    if (normalizedCrop != null) {
      left = (normalizedCrop.left * width).round().clamp(1, width - 2);
      top = (normalizedCrop.top * height).round().clamp(1, height - 2);
      right = (normalizedCrop.right * width).round().clamp(1, width - 2);
      bottom = (normalizedCrop.bottom * height).round().clamp(1, height - 2);
    }

    if (right <= left || bottom <= top) return 0;

    double sum = 0;
    int count = 0;

    for (int y = top; y <= bottom; y += step) {
      final row = y * rowStride;
      for (int x = left; x <= right; x += step) {
        final idx = row + x;
        final center = bytes[idx];
        final diff =
            (center - bytes[idx - 1]).abs() +
            (center - bytes[idx + 1]).abs() +
            (center - bytes[idx - rowStride]).abs() +
            (center - bytes[idx + rowStride]).abs();
        sum += diff / 4;
        count++;
      }
    }

    if (count == 0) return 0;
    final mean = sum / count;
    return mean.isFinite ? mean : 0;
  }

  void _handleCameraImage(CameraImage image) {
    if (!_isRealtimeAssessment || _isCapturing) return;
    if (!_isLiveIsolateReady || _liveSendPort == null) return;
    if (image.planes.length < 3) return;
    if (_isRealtimeProcessing) return;
    final now = DateTime.now();
    if (now.difference(_lastRealtimeRun) < _realtimeInterval) return;
    _lastRealtimeRun = now;
    _isRealtimeProcessing = true;

    try {
      final normalizedCrop = _normalizedCropRectForFrameGuide(
        previewWidth: image.width.toDouble(),
        previewHeight: image.height.toDouble(),
      );
      _updateQualityMetrics(image, normalizedCrop);

      var rgb = _convertYuv420ToRgb(
        width: image.width,
        height: image.height,
        bytesY: image.planes[0].bytes,
        bytesU: image.planes[1].bytes,
        bytesV: image.planes[2].bytes,
        yRowStride: image.planes[0].bytesPerRow,
        uvRowStride: image.planes[1].bytesPerRow,
        uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
        maxDimension: _liveProcessingMaxDimension,
      );

      if (normalizedCrop != null) {
        final rect = _cropRectFromNormalized(
          left: normalizedCrop.left,
          top: normalizedCrop.top,
          right: normalizedCrop.right,
          bottom: normalizedCrop.bottom,
          width: rgb.width,
          height: rgb.height,
        );
        if (rect != null) {
          rgb = img.copyCrop(
            rgb,
            x: rect.left.round(),
            y: rect.top.round(),
            width: rect.width.round(),
            height: rect.height.round(),
          );
        }
      }

      final cachedImageBytes = Uint8List.fromList(img.encodeJpg(rgb, quality: 92));
      widget.controller?.cacheLiveFrame(LiveFrameCache(
        imageBytes: cachedImageBytes,
        sharpnessScore: _liveSharpnessScore,
        framingScore: _liveFramingScore,
        assessment: _liveAssessment,
        confidence: _liveConfidence,
        boundingBox: _liveBoundingBox,
      ));

      final requestId = ++_liveRequestId;
      _pendingLiveRequestId = requestId;
      _liveSendPort?.send({
        'type': _liveIsolateProcess,
        'requestId': requestId,
        'width': image.width,
        'height': image.height,
        'yRowStride': image.planes[0].bytesPerRow,
        'uvRowStride': image.planes[1].bytesPerRow,
        'uvPixelStride': image.planes[1].bytesPerPixel ?? 1,
        'bytesY': TransferableTypedData.fromList([image.planes[0].bytes]),
        'bytesU': TransferableTypedData.fromList([image.planes[1].bytes]),
        'bytesV': TransferableTypedData.fromList([image.planes[2].bytes]),
        'crop': normalizedCrop == null
            ? null
            : {
                'left': normalizedCrop.left,
                'top': normalizedCrop.top,
                'right': normalizedCrop.right,
                'bottom': normalizedCrop.bottom,
              },
        'maxDimension': _liveProcessingMaxDimension,
      });
    } catch (e) {
      _isRealtimeProcessing = false;
      debugPrint('Live assessment frame enqueue failed: $e');
    }
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize!.height,
            height: controller.value.previewSize!.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Future<void> _startRealtimeAssessment() async {
    if (_isRealtimeAssessment) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    await _ensureLiveIsolateReady();
    if (!_isLiveIsolateReady) {
      if (!mounted) return;
      _showTopNotification('Live assessment failed to initialize.');
      return;
    }

    if (mounted) {
      setState(() {
        _isRealtimeAssessment = true;
        _liveAssessment = null;
        _liveConfidence = null;
        _liveSharpnessScore = null;
        _liveFramingScore = null;
        _liveBoundingBox = null;
        _smoothedBoundingBox = null;
      });
    } else {
      _isRealtimeAssessment = true;
    }
    widget.controller?.clearLiveFrameCache();

    if (controller.value.isStreamingImages) return;
    try {
      await controller.startImageStream(_handleCameraImage);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _isRealtimeAssessment = false);
      _showTopNotification(
        'Live assessment failed: ${e.description ?? e.code}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRealtimeAssessment = false);
      _showTopNotification('Live assessment failed to start.');
    }
  }

  void _stopRealtimeAssessment() {
    if (!_isRealtimeAssessment) return;
    _isRealtimeAssessment = false;
    _isRealtimeProcessing = false;
    _liveSharpnessScore = null;
    _liveFramingScore = null;
    _liveBoundingBox = null;
    _smoothedBoundingBox = null;
    _liveStaleTimer?.cancel();
    _liveStaleTimer = null;
    widget.controller?.clearLiveFrameCache();
    if (mounted) {
      setState(() {});
    }
    final controller = _cameraController;
    if (controller == null) return;
    if (!controller.value.isStreamingImages) return;
    unawaited(controller.stopImageStream().catchError((_) {}));
  }

  Future<void> _captureShutter() async {
    final controller = _cameraController;
    if (_isCapturing || controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isTakingPicture) return;

    setState(() => _isCapturing = true);
    try {
      if (_isRealtimeAssessment) {
        final cache = widget.controller?.consumeLiveFrameCache();
        if (cache != null &&
            cache.assessment != null &&
            cache.confidence != null) {
          final tempDir = Directory.systemTemp;
          final tempFile = File(
            '${tempDir.path}/live_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          await tempFile.writeAsBytes(cache.imageBytes, flush: true);

          widget.controller?.setLatestMeasuredTree(
            tree: MangroveTree(
              treeBounds: cache.boundingBox == null
                  ? null
                  : TreeBounds(
                      left: cache.boundingBox!.left,
                      top: cache.boundingBox!.top,
                      right: cache.boundingBox!.right,
                      bottom: cache.boundingBox!.bottom,
                    ),
            ),
            predictionConfidence: cache.confidence,
            capturedImagePath: tempFile.path,
            outcome: ScanOutcome.detected,
            predictedAssessment: cache.assessment,
          );

          if (!mounted) return;
          widget.onScanCompleted?.call();
          return;
        }
      }

      final picture = await controller.takePicture();
      final croppedImagePath = await _cropCapturedImageToFrame(picture.path);
      if (!mounted) return;
      final outcome = await _storeDetectedImageResult(croppedImagePath);
      if (!mounted) return;
      if (outcome != ScanOutcome.noMangroveDetected) {
        widget.onScanCompleted?.call();
      } else {
        _showTopNotification('No mangroves detected. Try a clearer scan.');
      }
    } on CameraException catch (e) {
      if (!mounted) return;
      _showTopNotification('Capture failed: ${e.description ?? e.code}');
    } catch (_) {
      if (!mounted) return;
      _showTopNotification('Unexpected scanner error.');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _handleUploadPhoto() async {
    if (_isCapturing || _isRealtimeAssessment) return;

    XFile? picked;
    try {
      picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    } on PlatformException catch (e) {
      _showTopNotification('Photo picker failed: ${e.message ?? e.code}');
      return;
    } catch (_) {
      _showTopNotification('Photo picker failed.');
      return;
    }

    if (!mounted || picked == null) return;

    setState(() => _isCapturing = true);
    try {
      final outcome = await _storeDetectedImageResult(picked.path);
      if (!mounted) return;
      if (outcome != ScanOutcome.noMangroveDetected) {
        widget.onScanCompleted?.call();
      } else {
        _showTopNotification('No mangroves detected. Try a clearer scan.');
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<String> _cropCapturedImageToFrame(String imagePath) async {
    final controller = _cameraController;
    if (controller == null || !mounted) return imagePath;

    final previewSize = controller.value.previewSize;
    if (previewSize == null) return imagePath;

    final previewWidth = previewSize.height;
    final previewHeight = previewSize.width;
    final previewCropRect = _previewCropRectForFrameGuide(
      previewWidth: previewWidth,
      previewHeight: previewHeight,
    );
    if (previewCropRect == null) return imagePath;

    try {
      final sourceBytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return imagePath;
      final oriented = img.bakeOrientation(decoded);

      final sourceW = oriented.width.toDouble();
      final sourceH = oriented.height.toDouble();
      final xScale = sourceW / previewWidth;
      final yScale = sourceH / previewHeight;

      final cropLeft = (previewCropRect.left * xScale).round().clamp(
        0,
        oriented.width - 1,
      );
      final cropTop = (previewCropRect.top * yScale).round().clamp(
        0,
        oriented.height - 1,
      );
      final cropRight = (previewCropRect.right * xScale).round().clamp(
        cropLeft + 1,
        oriented.width,
      );
      final cropBottom = (previewCropRect.bottom * yScale).round().clamp(
        cropTop + 1,
        oriented.height,
      );

      final cropWidth = cropRight - cropLeft;
      final cropHeight = cropBottom - cropTop;
      if (cropWidth <= 1 || cropHeight <= 1) return imagePath;

      final cropped = img.copyCrop(
        oriented,
        x: cropLeft,
        y: cropTop,
        width: cropWidth,
        height: cropHeight,
      );

      final extension = _fileExtension(imagePath);
      final croppedPath = imagePath.replaceFirst(
        RegExp(r'\.[^.]+$'),
        '_grid$extension',
      );
      await File(
        croppedPath,
      ).writeAsBytes(img.encodeJpg(cropped, quality: 95), flush: true);
      return croppedPath;
    } catch (e) {
      debugPrint('Failed to crop capture to frame guide: $e');
      return imagePath;
    }
  }

  String _fileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0) return '.jpg';
    final extension = path.substring(dotIndex).toLowerCase();
    if (extension.length > 8 || extension.contains('/')) return '.jpg';
    return extension;
  }

  void _showTopNotification(String message) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'notification',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) {
        final navigator = Navigator.of(context, rootNavigator: true);
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _TopNotificationContent(
                message: message,
                onDismiss: () {
                  if (navigator.mounted && navigator.canPop()) {
                    navigator.pop();
                  }
                },
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
}

class _TopNotificationContent extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopNotificationContent({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationContent> createState() =>
      _TopNotificationContentState();
}

class _TopNotificationContentState extends State<_TopNotificationContent> {
  bool _fadingOut = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _fadingOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _fadingOut ? 0 : 1,
      curve: Curves.easeIn,
      onEnd: _fadingOut ? widget.onDismiss : null,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF032221).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF00DF81).withValues(alpha: 0.35),
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
              const Icon(
                Icons.notifications_active,
                color: Color(0xFF00DF81),
                size: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                  child: Text(
                    widget.message,
                  style: const TextStyle(
                    color: Color(0xFFF1F7F6),
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
}
