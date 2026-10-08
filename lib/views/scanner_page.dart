import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:mangroveguardapp/theme/colors.dart';
import 'package:mangroveguardapp/models/mangrove_tree.dart';
import 'package:mangroveguardapp/models/result.dart';
import 'package:mangroveguardapp/services/mangrove_detector.dart';
import '../constants/app_constants.dart';
import 'scanner_camera.dart';
import 'scanner_controller.dart';
import 'scanner_isolate.dart';
import 'scanner_ui/detection_cards.dart';
import 'scanner_ui/menu.dart';
import 'scanner_ui/qr_dim_overlay_painter.dart';
import 'scanner_ui/frame_dim_overlay_painter.dart';

export 'scanner_controller.dart';

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

class _ScannerPageState extends State<ScannerPage>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  static const double _minPredictionConfidence = 0.10;
  static const Duration _realtimeInterval = Duration(milliseconds: 380);
  static const int _liveProcessingMaxDimension = 768;
  static const double _liveBoundingBoxSmoothing = 0.35;
  static const double _sharpnessLowVariance = 80;
  static const double _sharpnessHighVariance = 280;
  static const double _framingLowEdge = 6;
  static const double _framingHighEdge = 20;

  final CameraLifecycle _camera = CameraLifecycle();
  bool _isCapturing = false;
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
  bool _isQrScanning = false;
  bool _isQrVerifying = false;
  bool _isPaired = false;
  String? _qrVerificationMessage;
  String? _qrTemporaryError;
  MobileScannerController? _qrScannerController;
  StreamSubscription<BarcodeCapture>? _qrBarcodeSubscription;
  Timer? _qrErrorDismissTimer;
  Timer? _pairingStatusTimer;
  DateTime _lastRealtimeRun = DateTime.fromMillisecondsSinceEpoch(0);
  StabilityAssessment? _liveAssessment;
  double? _liveConfidence;
  double? _liveSharpnessScore;
  double? _liveFramingScore;
  Rect? _liveBoundingBox;
  Rect? _smoothedBoundingBox;
  CameraController? _previewController;
  Widget? _cachedCameraPreview;
  Isolate? _liveIsolate;
  ReceivePort? _liveReceivePort;
  final LiveIsolateMessageHandler _liveIsolateHandler =
      LiveIsolateMessageHandler();
  bool _isLiveIsolateStarting = false;
  Completer<void>? _liveReadyCompleter;
  int _liveRequestId = 0;
  Uint8List? _liveModelBytes;
  Timer? _liveStaleTimer;
  bool _isMenuExpanded = false;
  late final AnimationController _menuController;
  late final Animation<double> _menuSpin;
  late final Animation<double> _menuUpload;
  late final Animation<double> _menuQr;
  late final Animation<double> _menuGuidance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?.addListener(_handleControllerSignal);
    _lastShutterSignal = widget.controller?.shutterSignal ?? 0;
    _lastRealtimeSignal = widget.controller?.isRealtimeAssessment ?? false;
    _restorePairedState();
    _startPairingStatusPolling();
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scheduleCameraInit(),
      );
    }
    _initDetector();
    unawaited(_ensureLiveIsolateReady());
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _menuSpin = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeOutCubic),
    );
    _menuUpload = CurvedAnimation(
      parent: _menuController,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
    );
    _menuQr = CurvedAnimation(
      parent: _menuController,
      curve: const Interval(0.12, 0.54, curve: Curves.easeOutCubic),
    );
    _menuGuidance = CurvedAnimation(
      parent: _menuController,
      curve: const Interval(0.24, 0.66, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _restorePairedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(AppConstants.pairedServerUrlKey);
      final deviceId = prefs.getString(AppConstants.deviceIdKey);
      if (savedUrl != null &&
          savedUrl.trim().isNotEmpty &&
          deviceId != null &&
          deviceId.trim().isNotEmpty) {
        setState(() {
          _isPaired = true;
        });
        // Reconcile immediately so a stale local flag can't linger when the
        // server has unpaired this device while the app was closed.
        unawaited(_verifyServerPairing());
      }
    } catch (_) {}
  }

  void _startPairingStatusPolling() {
    _pairingStatusTimer?.cancel();
    _pairingStatusTimer = Timer.periodic(const Duration(seconds: 10), (
      _,
    ) async {
      if (!mounted) return;
      await _verifyServerPairing();
    });
  }

  Future<void> _verifyServerPairing() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(AppConstants.pairedServerUrlKey);
    final deviceId = prefs.getString(AppConstants.deviceIdKey);

    if (savedUrl == null ||
        savedUrl.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty) {
      return;
    }

    try {
      final baseUrl = savedUrl.replaceAll(RegExp(r'/+$'), '');
      final response = await http
          .get(Uri.parse('$baseUrl/${AppConstants.apiDevices}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final devices = jsonDecode(response.body) as List<dynamic>;
        final device = devices.cast<Map<String, dynamic>>().firstWhere(
          (d) =>
              d['deviceId'] == deviceId || d['device_id'] == deviceId,
          orElse: () => <String, dynamic>{},
        );

        // /api/devices no longer exposes lastPairedToken (secret-equivalent);
        // it returns `isPaired` (1/0 or true/false) instead. Checking the old
        // field always yielded null and incorrectly unpaired the app.
        final rawPaired = device.isEmpty
            ? null
            : (device.containsKey('isPaired')
                  ? device['isPaired']
                  : device['is_paired']);
        final stillPaired =
            device.isNotEmpty &&
            (rawPaired == 1 ||
                rawPaired == true ||
                rawPaired == '1' ||
                rawPaired == 'true');
        if (!stillPaired) {
          if (_isPaired) {
            await prefs.remove(AppConstants.pairedServerUrlKey);
            if (mounted) {
              setState(() {
                _isPaired = false;
                _qrVerificationMessage = null;
                _qrTemporaryError = null;
              });
            }
          }
        } else if (!_isPaired && mounted) {
          setState(() {
            _isPaired = true;
          });
        }
      }
    } on SocketException catch (_) {
    } on TimeoutException catch (_) {
    } on HttpException catch (_) {
    } catch (_) {}
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
      _camera.resetPermissionState();
      unawaited(_verifyServerPairing());
      _resumeCameraForTabSwitch();
    } else if (!widget.isActive && oldWidget.isActive) {
      _collapseMenu();
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
    unawaited(_camera.disposeControllerAsync());
    _detector?.dispose();
    unawaited(_pauseQrScanning());
    _clearQrErrorDismiss();
    _pairingStatusTimer?.cancel();
    _menuController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_verifyServerPairing());
      if (_camera.isPermissionDenied) {
        unawaited(_recheckDeniedPermission());
      } else if (!_isQrScanning) {
        _scheduleCameraInit();
      }
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      widget.controller?.stopRealtimeAssessment();
      _stopRealtimeAssessment();
      _disposeLiveIsolate();
      unawaited(_camera.disposeControllerAsync());
      _camera.controller = null;
      if (_isQrScanning) {
        unawaited(_pauseQrScanning());
      }
    }
  }

  Future<void> _recheckDeniedPermission() async {
    if (!mounted || _camera.isCheckingPermission) return;
    _camera.isCheckingPermission = true;

    try {
      final status = await Permission.camera.status;
      if (status.isGranted) {
        _camera.resetPermissionState();
        await _initCamera();
      }
    } catch (_) {
      debugPrint('Permission recheck failed:');
    } finally {
      _camera.isCheckingPermission = false;
    }
  }

  void _scheduleCameraInit() {
    if (!mounted) return;
    if (!widget.isActive) return;
    if (_camera.isPermissionDenied) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.detached) {
      return;
    }
    unawaited(_ensureLiveIsolateReady());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      if (_camera.isPermissionDenied) return;
      final controller = _camera.controller;
      if (controller != null && controller.value.isInitialized) {
        unawaited(_resumeCameraForTabSwitch());
      } else {
        unawaited(_initCamera());
      }
    });
  }

  Future<void> _initCamera() async {
    if (!mounted || _camera.initInFlight || _camera.isCheckingPermission) {
      return;
    }
    if (_camera.isPermissionDenied) return;
    _camera.initInFlight = true;
    _camera.isCheckingPermission = true;
    setState(() {
      _camera.isInitializing = true;
      _camera.cameraError = null;
    });

    try {
      final granted = await _camera.requestCameraPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() {
          _camera.cameraError = _camera.isPermanentlyDenied
              ? 'Camera permission is permanently denied. Please enable camera access in app settings.'
              : 'Camera permission is required to scan mangroves.';
          _camera.isInitializing = false;
        });
        return;
      }

      final controller = await _camera.createController();
      if (controller == null) {
        if (!mounted) return;
        setState(() {
          _camera.cameraError = 'No camera available on this device.';
          _camera.isInitializing = false;
        });
        return;
      }

      try {
        await controller.initialize();
      } on CameraException catch (e) {
        if (!mounted) return;
        setState(() {
          _camera.cameraError = 'Camera error: ${e.description ?? e.code}';
          _camera.isInitializing = false;
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

      await _camera.disposeControllerAsync();
      _camera.controller = controller;
      setState(() {
        _camera.isInitializing = false;
        _camera.cameraError = null;
      });

      unawaited(_camera.configureForFastCapture(controller));

      if (_lastRealtimeSignal) {
        unawaited(_startRealtimeAssessment());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _camera.cameraError = 'Unable to initialize camera.';
        _camera.isInitializing = false;
      });
    } finally {
      _camera.initInFlight = false;
      _camera.isCheckingPermission = false;
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
    if (_liveIsolateHandler.isReady) return;
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
      _liveIsolate = await Isolate.spawn(liveAssessmentIsolate, {
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
    _liveIsolateHandler.isReady = false;
    _isLiveIsolateStarting = false;
    _liveStaleTimer?.cancel();
    _liveStaleTimer = null;
    final completer = _liveReadyCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _liveReadyCompleter = null;
    try {
      _liveIsolateHandler.sendPort?.send({'type': liveIsolateStop});
    } catch (_) {}
    _liveIsolateHandler.sendPort = null;
    _liveIsolateHandler.pendingRequestId = 0;
    _liveReceivePort?.close();
    _liveReceivePort = null;
    final isolate = _liveIsolate;
    _liveIsolate = null;
    if (isolate != null) {
      try {
        isolate.kill(priority: Isolate.immediate);
      } catch (_) {}
    }
  }

  void _handleLiveIsolateMessage(dynamic message) {
    final event = _liveIsolateHandler.handle(message);
    if (event is LiveIsolateReadyEvent) {
      final completer = _liveReadyCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      return;
    }

    if (event is LiveIsolateResultEvent) {
      if (!_isRealtimeAssessment) {
        _isRealtimeProcessing = false;
        return;
      }
      final confidence = event.confidence;
      final bool isConfident =
          confidence != null && confidence >= _minPredictionConfidence;
      StabilityAssessment? assessment;
      if (event.assessmentName != null && isConfident) {
        try {
          assessment = StabilityAssessment.values.byName(event.assessmentName!);
        } on StateError {
          assessment = null;
        }
      }
      final Rect? boundingBox = isConfident ? event.boundingBox : null;

      if (mounted) {
        setState(() {
          _liveConfidence = confidence;
          if (isConfident) {
            _liveAssessment = assessment;
            if (boundingBox != null) {
              _smoothedBoundingBox ??= boundingBox;
              _smoothedBoundingBox = Rect.fromLTRB(
                _liveBoundingBoxSmoothing * boundingBox.left +
                    (1 - _liveBoundingBoxSmoothing) *
                        _smoothedBoundingBox!.left,
                _liveBoundingBoxSmoothing * boundingBox.top +
                    (1 - _liveBoundingBoxSmoothing) * _smoothedBoundingBox!.top,
                _liveBoundingBoxSmoothing * boundingBox.right +
                    (1 - _liveBoundingBoxSmoothing) *
                        _smoothedBoundingBox!.right,
                _liveBoundingBoxSmoothing * boundingBox.bottom +
                    (1 - _liveBoundingBoxSmoothing) *
                        _smoothedBoundingBox!.bottom,
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
                  (1 - _liveBoundingBoxSmoothing) *
                      _smoothedBoundingBox!.bottom,
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
        _liveStaleTimer = Timer(
          const Duration(seconds: 2),
          _clearStaleLiveAssessment,
        );
      }
      return;
    }

    if (event is LiveIsolateErrorEvent) {
      _isRealtimeProcessing = false;
      final completer = _liveReadyCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      debugPrint('Live assessment isolate error: ${event.error}');
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
    _camera.resetPermissionState();
    unawaited(_initCamera());
  }

  Future<void> _pauseCameraForTabSwitch() async {
    _stopRealtimeAssessment();
    _disposeLiveIsolate();
    _camera.stopImageStream();
    _camera.initInFlight = false;
    if (mounted) {
      setState(() {
        _camera.isInitializing = false;
        _camera.cameraError = null;
      });
    }
  }

  Future<void> _resumeCameraForTabSwitch() async {
    if (!mounted) return;
    if (_camera.isPermissionDenied) return;

    final controller = _camera.controller;
    if (controller != null && controller.value.isInitialized) {
      _camera.startImageStream(_handleCameraImage);

      if (_lastRealtimeSignal) {
        unawaited(_startRealtimeAssessment());
      }

      setState(() {
        _camera.isInitializing = false;
        _camera.cameraError = null;
      });
    } else {
      _scheduleCameraInit();
    }
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

    final result = await detector.detect(imagePath);
    return switch (result) {
      Ok(value: final detection) => _handleDetectionSuccess(
        detection,
        imagePath,
      ),
      Err(error: final error) => _handleDetectionFailure(error, imagePath),
    };
  }

  ScanOutcome _handleDetectionSuccess(
    MangroveDetectionResult detection,
    String imagePath,
  ) {
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
  }

  ScanOutcome _handleDetectionFailure(DetectionError error, String imagePath) {
    debugPrint('Detector failed: ${error.message}');
    _storeCapturedImageResult(imagePath);
    if (!mounted) return ScanOutcome.captureOnly;
    _showTopNotification(error.message);
    return ScanOutcome.captureOnly;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cacheFrameRectIfPossible();
    });

    if (_camera.isInitializing) {
      return const Scaffold(
        backgroundColor: AppColors.richBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.caribbeanGreen),
              SizedBox(height: 20),
              Text(
                'Initializing Scanner...',
                style: TextStyle(color: AppColors.antiFlashWhite, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_camera.isPermissionDenied) {
      return Scaffold(
        backgroundColor: AppColors.richBlack,
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
                  _camera.cameraError ??
                      'Camera permission is required to scan mangroves.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.antiFlashWhite,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _camera.isPermanentlyDenied
                          ? () => openAppSettings()
                          : _resetPermissionStateAndRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.caribbeanGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _camera.isPermanentlyDenied ? 'Open Settings' : 'Retry',
                        style: const TextStyle(
                          color: AppColors.richBlack,
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

    if (_camera.cameraError != null) {
      final isPermanentlyDenied =
          _camera.cameraError!.contains('permanently denied') ||
          _camera.cameraError!.contains('app settings');
      return Scaffold(
        backgroundColor: AppColors.richBlack,
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
                  _camera.cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.antiFlashWhite,
                    fontSize: 15,
                  ),
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
                        backgroundColor: AppColors.caribbeanGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: AppColors.richBlack,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isPermanentlyDenied)
                      OutlinedButton(
                        onPressed: () => openAppSettings(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.antiFlashWhite,
                          side: const BorderSide(
                            color: AppColors.caribbeanGreen,
                          ),
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
      backgroundColor: AppColors.richBlack,
      body: Stack(
        children: [
          if (!_isQrScanning)
            Positioned.fill(
              child: RepaintBoundary(child: _buildCameraPreview()),
            ),
          if (!_isQrScanning && !_isRealtimeAssessment)
            Positioned.fill(
              child: CustomPaint(painter: const FrameDimOverlayPainter()),
            ),
          if (!_isQrScanning) _buildFrameGuide(),
          if (_isQrScanning) _buildQrScannerOverlay(),
          if (!_isQrScanning)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _isCapturing ? 1 : 0,
                  child: Container(color: Colors.white.withValues(alpha: 0.14)),
                ),
              ),
            ),
          if (_isRealtimeAssessment)
            BoundingBoxOverlay(
              boundingBox: _liveBoundingBox,
              frameRect: _lastFrameRectInViewport,
              assessment: _liveAssessment,
            ),
          if (_isRealtimeAssessment) _buildLiveAssessmentIndicator(),
          if (_isRealtimeAssessment)
            LiveDetectionCard(
              assessment: _liveBoundingBox == null ? null : _liveAssessment,
            ),
          _buildScannerMenu(),
        ],
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
    if (!_liveIsolateHandler.isReady || _liveIsolateHandler.sendPort == null) {
      return;
    }
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

      var rgb = convertYuv420ToRgb(
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
        final rect = cropRectFromNormalized(
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

      final cachedImageBytes = Uint8List.fromList(
        img.encodeJpg(rgb, quality: 92),
      );
      widget.controller?.cacheLiveFrame(
        LiveFrameCache(
          imageBytes: cachedImageBytes,
          sharpnessScore: _liveSharpnessScore,
          framingScore: _liveFramingScore,
          assessment: _liveAssessment,
          confidence: _liveConfidence,
          boundingBox: _liveBoundingBox,
        ),
      );

      final requestId = ++_liveRequestId;
      _liveIsolateHandler.pendingRequestId = requestId;
      _liveIsolateHandler.sendPort?.send({
        'type': liveIsolateProcess,
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
    final controller = _camera.controller;
    if (controller == null || !controller.value.isInitialized) {
      _previewController = null;
      _cachedCameraPreview = null;
      return const ColoredBox(color: Colors.black);
    }
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      _previewController = null;
      _cachedCameraPreview = null;
      return const ColoredBox(color: Colors.black);
    }

    if (_previewController != controller || _cachedCameraPreview == null) {
      _previewController = controller;
      _cachedCameraPreview = ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(controller),
            ),
          ),
        ),
      );
    }

    return _cachedCameraPreview!;
  }

  Widget _buildFrameGuide() {
    const width = 260.0;
    const height = 420.0;
    const frameAlignment = Alignment(0, -0.50);

    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frameLeft =
                (constraints.maxWidth - width) / 2 +
                frameAlignment.x * (constraints.maxWidth - width) / 2;
            final frameTop =
                (constraints.maxHeight - height) / 2 +
                frameAlignment.y * (constraints.maxHeight - height) / 2;

            return Stack(
              children: [
                Positioned(
                  left: frameLeft,
                  top: frameTop,
                  child: Container(
                    key: _frameGuideInnerKey,
                    width: width,
                    height: height,
                    decoration: _isRealtimeAssessment
                        ? null
                        : BoxDecoration(
                            border: Border.all(
                              color: AppColors.caribbeanGreen,
                              width: 2.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                  ),
                ),
                if (!_isRealtimeAssessment)
                  Positioned(
                    left: frameLeft,
                    top: frameTop + height + 10,
                    child: Container(
                      width: width,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.darkGreen.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.caribbeanGreen.withValues(
                            alpha: 0.32,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Center the trunk and visible roots inside the frame.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.antiFlashWhite.withValues(
                            alpha: 0.86,
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQrScannerOverlay() {
    final controller = _qrScannerController;
    if (controller == null) {
      return const ColoredBox(color: Colors.transparent);
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Stack(
          children: [
            MobileScanner(controller: controller, onDetect: _onQrCodeDetected),
            _buildQrDimOverlay(),
            _buildQrViewfinder(),
            _buildQrScanHint(),
            if (_isQrVerifying) _buildQrVerifyingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildQrDimOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: const QrDimOverlayPainter()),
      ),
    );
  }

  Widget _buildQrViewfinder() {
    final size = MediaQuery.of(context).size;
    const cutoutSize = 250.0;
    final frameTop = (size.height - cutoutSize) / 2 - 40;

    return Positioned(
      top: frameTop,
      left: (size.width - cutoutSize) / 2,
      child: IgnorePointer(
        child: Container(
          width: cutoutSize,
          height: cutoutSize,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.caribbeanGreen, width: 2.5),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildQrScanHint() {
    final size = MediaQuery.of(context).size;
    const cutoutSize = 250.0;
    const hintWidth = 250.0;
    final frameTop = (size.height - cutoutSize) / 2 - 40;

    return Positioned(
      top: frameTop + cutoutSize + 10,
      left: (size.width - hintWidth) / 2,
      child: IgnorePointer(
        child: Container(
          width: hintWidth,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.darkGreen.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.caribbeanGreen.withValues(alpha: 0.32),
              width: 1,
            ),
          ),
          child: Text(
            'Align the dashboard QR code inside the frame.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.antiFlashWhite.withValues(alpha: 0.86),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrVerifyingOverlay() {
    final isSuccess = _qrVerificationMessage?.contains('success') ?? false;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.richBlack.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSuccess
                ? AppColors.caribbeanGreen.withValues(alpha: 0.8)
                : AppColors.caribbeanGreen.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSuccess)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.caribbeanGreen,
                size: 48,
              )
            else
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.caribbeanGreen,
                ),
                strokeWidth: 3,
              ),
            const SizedBox(height: 16),
            Text(
              _qrVerificationMessage ?? 'Verifying connection...',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.antiFlashWhite,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRealtimeAssessment() async {
    if (_isRealtimeAssessment) return;
    final controller = _camera.controller;
    if (controller == null || !controller.value.isInitialized) return;
    await _ensureLiveIsolateReady();
    if (!_liveIsolateHandler.isReady) {
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
    final controller = _camera.controller;
    if (controller == null) return;
    if (!controller.value.isStreamingImages) return;
    unawaited(controller.stopImageStream().catchError((_) {}));
  }

  Future<void> _captureShutter() async {
    final controller = _camera.controller;
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
    final controller = _camera.controller;
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

  Future<void> _toggleQrScanning() async {
    if (_isPaired) {
      await _unpair();
      return;
    }

    if (_isQrScanning) {
      await _stopQrScanning();
    } else {
      await _startQrScanning();
    }
  }

  Future<void> _unpair() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGreen.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: AppColors.caribbeanGreen.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        title: const Text(
          'Unpair device?',
          style: TextStyle(
            color: AppColors.antiFlashWhite,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'This will remove the saved server connection.',
          style: TextStyle(
            color: AppColors.antiFlashWhite.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.caribbeanGreen,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.caribbeanGreen,
            ),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(AppConstants.pairedServerUrlKey);
    final deviceId = prefs.getString(AppConstants.deviceIdKey);

    if (savedUrl != null && deviceId != null && deviceId.isNotEmpty) {
      try {
        final baseUrl = savedUrl.replaceAll(RegExp(r'/+$'), '');
        await http
            .post(
              Uri.parse('$baseUrl/${AppConstants.apiPairUnpair}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'deviceId': deviceId}),
            )
            .timeout(const Duration(seconds: 5));
      } on SocketException catch (_) {
      } on TimeoutException catch (_) {
      } on HttpException catch (_) {}
    }

    await prefs.remove(AppConstants.pairedServerUrlKey);
    setState(() {
      _isPaired = false;
      _qrVerificationMessage = null;
      _qrTemporaryError = null;
    });
  }

  Future<void> _startQrScanning() async {
    if (_isQrScanning) return;

    _collapseMenu();
    await _camera.disposeControllerAsync();

    setState(() {
      _isQrScanning = true;
    });

    try {
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      await controller.start();

      setState(() {
        _qrScannerController = controller;
      });

      _qrBarcodeSubscription = controller.barcodes.listen(
        _onQrCodeDetected,
        onError: (error) {
          if (mounted) {
            _showTopNotification('QR scanner error: $error');
            setState(() {
              _isQrScanning = false;
            });
            _scheduleCameraInit();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        _showTopNotification('Failed to start QR scanner: ${e.toString()}');
        setState(() {
          _isQrScanning = false;
        });
        _scheduleCameraInit();
      }
    }
  }

  Future<void> _stopQrScanning() async {
    await _pauseQrScanning();
    _qrScannerController = null;
    _clearQrErrorDismiss();
    if (mounted) {
      setState(() {
        _isQrScanning = false;
        _isQrVerifying = false;
        _qrVerificationMessage = null;
        _qrTemporaryError = null;
      });
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleCameraInit();
    });
  }

  Future<void> _pauseQrScanning() async {
    final controller = _qrScannerController;
    if (controller != null) {
      try {
        await controller.stop();
      } catch (_) {}
    }
    await _qrBarcodeSubscription?.cancel();
    _qrBarcodeSubscription = null;
    try {
      controller?.dispose();
    } catch (_) {}
  }

  void _onQrCodeDetected(BarcodeCapture capture) {
    if (_isQrVerifying || _qrScannerController == null || _isPaired) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!.trim();
    if (rawValue.isEmpty) return;

    final uri = Uri.tryParse(rawValue);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      _showTopNotification('Invalid QR code. Expected a server URL.');
      return;
    }

    _pauseQrAndVerify(uri.toString());
  }

  void _pauseQrAndVerify(String serverUrl) {
    final controller = _qrScannerController;
    if (controller != null) {
      try {
        controller.stop();
      } catch (_) {}
    }

    setState(() {
      _isQrVerifying = true;
      _qrVerificationMessage = 'Pairing device...';
    });

    _processQrCode(serverUrl);
  }

  Future<void> _processQrCode(String serverUrl) async {
    final uri = Uri.parse(serverUrl);
    final normalizedUrl = uri.origin.replaceAll(RegExp(r'/+$'), '');
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      _qrTemporaryError = 'Invalid QR code. Missing pairing token.';
      _scheduleQrErrorDismiss();
      setState(() {
        _isQrVerifying = false;
        _qrVerificationMessage = null;
      });
      final controller = _qrScannerController;
      if (controller != null) {
        try {
          await controller.start();
        } catch (_) {}
      }
      return;
    }
    final success = await _attemptPairing(normalizedUrl, token);
    if (!mounted) return;

    if (success) {
      setState(() {
        _qrVerificationMessage = 'Paired successfully!';
        _isPaired = true;
      });

      await Future.delayed(const Duration(milliseconds: 800));

      _showTopNotification('Device paired successfully!');

      await _stopQrScanning();
    } else {
      _qrTemporaryError = 'Connection failed. Please try scanning again.';
      _scheduleQrErrorDismiss();

      setState(() {
        _isQrVerifying = false;
        _qrVerificationMessage = null;
      });

      final controller = _qrScannerController;
      if (controller != null) {
        try {
          await controller.start();
        } catch (_) {}
      }
    }
  }

  void _scheduleQrErrorDismiss() {
    _qrErrorDismissTimer?.cancel();
    _qrErrorDismissTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _qrTemporaryError = null;
        });
      }
    });
  }

  void _clearQrErrorDismiss() {
    _qrErrorDismissTimer?.cancel();
    _qrErrorDismissTimer = null;
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return info.device ?? info.model ?? 'Android Device';
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return info.name ?? 'iOS Device';
    } else if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      return info.prettyName ?? info.name ?? 'Linux Device';
    } else if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      return info.computerName ?? 'Windows Device';
    } else if (Platform.isMacOS) {
      final info = await deviceInfo.macOsInfo;
      return info.computerName ?? 'macOS Device';
    }
    return 'Unknown Device';
  }

  Future<bool> _attemptPairing(String baseUrl, String? token) async {
    try {
      setState(() {
        _qrVerificationMessage = 'Verifying server...';
      });

      final healthResponse = await http
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      if (healthResponse.statusCode != 200) {
        return false;
      }

      final healthDecoded = jsonDecode(healthResponse.body);
      if (healthDecoded is! Map<String, dynamic> ||
          healthDecoded['status'] != 'ok' ||
          healthDecoded['db'] != true) {
        return false;
      }
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } on FormatException catch (_) {
      return false;
    } on ArgumentError catch (_) {
      return false;
    } catch (_) {
      return false;
    }

    final endpoints = [
      Uri.parse('$baseUrl/${AppConstants.apiScans}'),
      Uri.parse('$baseUrl/${AppConstants.apiPairQr}'),
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .get(endpoint)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          if (token != null && token.isNotEmpty) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final deviceId =
                  prefs.getString(AppConstants.deviceIdKey) ??
                  'device-${DateTime.now().millisecondsSinceEpoch}';
              if (!prefs.containsKey(AppConstants.deviceIdKey)) {
                await prefs.setString(AppConstants.deviceIdKey, deviceId);
              }

              final confirmResponse = await http
                  .post(
                    Uri.parse('$baseUrl/${AppConstants.apiPairConfirm}'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'token': token,
                      'deviceId': deviceId,
                      'deviceName': await _getDeviceName(),
                    }),
                  )
                  .timeout(const Duration(seconds: 5));
              if (confirmResponse.statusCode >= 400) {
                String errorMessage =
                    'Pair confirm rejected: ${confirmResponse.statusCode}';
                try {
                  final decoded = jsonDecode(confirmResponse.body);
                  if (decoded is Map<String, dynamic>) {
                    final serverError = decoded['error'] as String?;
                    final serverCode = decoded['code'] as String?;
                    if (serverError != null && serverError.isNotEmpty) {
                      errorMessage = serverCode != null && serverCode.isNotEmpty
                          ? '$serverError (code: $serverCode)'
                          : serverError;
                    }
                  }
                } on FormatException catch (_) {
                } on ArgumentError catch (_) {}
                debugPrint(errorMessage);
                return false;
              }
            } catch (e) {
              debugPrint('Pair confirm failed: $e');
              return false;
            }
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.pairedServerUrlKey, baseUrl);
          return true;
        }
      } on SocketException {
        continue;
      } on TimeoutException {
        continue;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  void _toggleMenu() {
    if (!mounted) return;
    setState(() {
      _isMenuExpanded = !_isMenuExpanded;
    });
    if (_isMenuExpanded) {
      _menuController.forward();
    } else {
      _menuController.reverse();
    }
  }

  void _collapseMenu() {
    if (!_isMenuExpanded) return;
    if (mounted) {
      setState(() {
        _isMenuExpanded = false;
      });
    } else {
      _isMenuExpanded = false;
    }
    _menuController.reverse();
  }

  void _handleMenuAction(VoidCallback action) {
    _collapseMenu();
    action();
  }

  String get _guidanceLabel {
    if (_isQrScanning) return 'QR Scanner Guidance';
    if (_isRealtimeAssessment) return 'Live Scan Guidance';
    return 'Capture Guidance';
  }

  VoidCallback get _guidanceAction {
    if (_isQrScanning) return _showQrScannerGuidance;
    if (_isRealtimeAssessment) return _showLiveScanGuidance;
    return _showCaptureGuidance;
  }

  Widget _buildLiveAssessmentIndicator() {
    final statusText = _liveAssessment == null
        ? 'Analyzing frame'
        : _liveAssessment!.label;

    return Positioned(
      top: 10,
      right: 16,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 176),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkGreen.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.caribbeanGreen.withValues(alpha: 0.55),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.caribbeanGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Assessment',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.antiFlashWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.antiFlashWhite.withValues(
                            alpha: 0.74,
                          ),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildScannerMenu() {
    final isQrScreen = _isQrScanning;
    final isPaired = _isPaired;
    return Positioned(
      right: 16,
      bottom: 116,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IgnorePointer(
            ignoring: !_isMenuExpanded,
            child: ScannerMenuAction(
              icon: Icons.cloud_upload_rounded,
              label: 'Upload',
              animation: _menuUpload,
              onTap: () => _handleMenuAction(_handleUploadPhoto),
            ),
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: !_isMenuExpanded,
            child: ScannerMenuAction(
              icon: isPaired
                  ? Icons.link_off_rounded
                  : isQrScreen
                  ? Icons.photo_camera_rounded
                  : Icons.qr_code_scanner_rounded,
              label: isPaired
                  ? 'Unpair'
                  : isQrScreen
                  ? 'Camera'
                  : 'Scan QR',
              animation: _menuQr,
              onTap: () => _handleMenuAction(
                isPaired
                    ? _unpair
                    : isQrScreen
                    ? _stopQrScanning
                    : _toggleQrScanning,
              ),
            ),
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: !_isMenuExpanded,
            child: ScannerMenuAction(
              icon: Icons.info_rounded,
              label: _guidanceLabel,
              animation: _menuGuidance,
              onTap: () => _handleMenuAction(_guidanceAction),
            ),
          ),
          const SizedBox(height: 14),
          _buildScannerMenuButton(),
        ],
      ),
    );
  }

  Widget _buildScannerMenuButton() {
    return Semantics(
      button: true,
      label: _isMenuExpanded ? 'Close scanner menu' : 'Open scanner menu',
      child: GestureDetector(
        onTap: _toggleMenu,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.darkGreen.withValues(alpha: 0.92),
            border: Border.all(
              color: _isMenuExpanded
                  ? AppColors.caribbeanGreen.withValues(alpha: 0.85)
                  : AppColors.caribbeanGreen.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.caribbeanGreen.withValues(alpha: 0.18),
                blurRadius: 10,
                spreadRadius: 0.2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: RotationTransition(
            turns: _menuSpin,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                _isMenuExpanded ? Icons.close_rounded : Icons.menu_rounded,
                key: ValueKey<bool>(_isMenuExpanded),
                color: AppColors.antiFlashWhite,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCaptureGuidance() {
    _showGuidanceDialog(
      title: 'Capture Guidance',
      steps: const <String>[
        'Place the mangrove root structure inside the capture frame.',
        'Keep the trunk and visible roots centered before taking the photo.',
        'Tap the shutter once the subject is clear and steady.',
        'Avoid glare, heavy shadows, or cropped roots so the saved scan is easier to assess.',
        'Use upload for an existing photo instead of the camera capture.',
      ],
    );
  }

  void _showLiveScanGuidance() {
    _showGuidanceDialog(
      title: 'Live Scan Guidance',
      steps: const <String>[
        'Live assessment is active while the camera analyzes frames on this device.',
        'Keep the mangrove root structure inside the frame guide until the detection box appears.',
        'Use the stability label and colored detection box as the current live assessment.',
        'Tap the shutter to save the current live assessment as a scan.',
        'Hold the shutter again to stop live assessment and return to standard capture.',
      ],
    );
  }

  void _showQrScannerGuidance() {
    _showGuidanceDialog(
      title: 'QR Scanner Guidance',
      steps: const <String>[
        'Scan the QR code displayed on the MangroveGuard web dashboard.',
        'Ensure the server URL is reachable from this device.',
        'The QR code must contain a valid pairing token to connect.',
        'Once paired, this device can sync scans to the configured server.',
        'Use the Camera action in this menu to return to field capture.',
      ],
    );
  }

  void _showGuidanceDialog({
    required String title,
    required List<String> steps,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColors.darkGreen.withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: AppColors.caribbeanGreen.withValues(alpha: 0.4),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_rounded,
                      color: AppColors.caribbeanGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.antiFlashWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                for (final step in steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.caribbeanGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(
                              color: AppColors.antiFlashWhite,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.caribbeanGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
              child: TopNotificationContent(
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
