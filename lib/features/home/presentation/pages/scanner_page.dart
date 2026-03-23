import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../models/mangrove_tree.dart';

const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);

class ScannerPageController extends ChangeNotifier {
  int _shutterSignal = 0;
  MeasuredTreeResult? _latestMeasuredTreeResult;

  int get shutterSignal => _shutterSignal;

  void triggerShutter() {
    _shutterSignal++;
    notifyListeners();
  }

  // Call this from the measurement/inference pipeline when a tree model is ready.
  void setLatestMeasuredTree({
    required MangroveTree tree,
    double metersPerPixel = 0.003,
    String? capturedImagePath,
    Uint8List? rootMaskBytes,
    int? rootMaskWidth,
    int? rootMaskHeight,
    Uint8List? trunkMaskBytes,
    int? trunkMaskWidth,
    int? trunkMaskHeight,
  }) {
    _latestMeasuredTreeResult = MeasuredTreeResult(
      tree: tree,
      metersPerPixel: metersPerPixel,
      capturedImagePath: capturedImagePath,
      rootMaskBytes: rootMaskBytes,
      rootMaskWidth: rootMaskWidth,
      rootMaskHeight: rootMaskHeight,
      trunkMaskBytes: trunkMaskBytes,
      trunkMaskWidth: trunkMaskWidth,
      trunkMaskHeight: trunkMaskHeight,
    );
  }

  MeasuredTreeResult? consumeLatestMeasuredTreeResult() {
    final result = _latestMeasuredTreeResult;
    _latestMeasuredTreeResult = null;
    return result;
  }
}

class MeasuredTreeResult {
  final MangroveTree tree;
  final double metersPerPixel;
  final String? capturedImagePath;
  final Uint8List? rootMaskBytes;
  final int? rootMaskWidth;
  final int? rootMaskHeight;
  final Uint8List? trunkMaskBytes;
  final int? trunkMaskWidth;
  final int? trunkMaskHeight;

  const MeasuredTreeResult({
    required this.tree,
    required this.metersPerPixel,
    this.capturedImagePath,
    this.rootMaskBytes,
    this.rootMaskWidth,
    this.rootMaskHeight,
    this.trunkMaskBytes,
    this.trunkMaskWidth,
    this.trunkMaskHeight,
  });
}

class _InferenceResult {
  final MangroveTree tree;
  final double metersPerPixel;
  final Uint8List? rootMaskBytes;
  final int? rootMaskWidth;
  final int? rootMaskHeight;
  final Uint8List? trunkMaskBytes;
  final int? trunkMaskWidth;
  final int? trunkMaskHeight;

  const _InferenceResult({
    required this.tree,
    required this.metersPerPixel,
    this.rootMaskBytes,
    this.rootMaskWidth,
    this.rootMaskHeight,
    this.trunkMaskBytes,
    this.trunkMaskWidth,
    this.trunkMaskHeight,
  });
}

class _ExtractedTree {
  final MangroveTree tree;
  final Uint8List? rootMaskBytes;
  final int? rootMaskWidth;
  final int? rootMaskHeight;
  final Uint8List? trunkMaskBytes;
  final int? trunkMaskWidth;
  final int? trunkMaskHeight;

  const _ExtractedTree({
    required this.tree,
    this.rootMaskBytes,
    this.rootMaskWidth,
    this.rootMaskHeight,
    this.trunkMaskBytes,
    this.trunkMaskWidth,
    this.trunkMaskHeight,
  });
}

class ScannerPage extends StatefulWidget {
  final ScannerPageController? controller;
  final VoidCallback? onScanCompleted;

  const ScannerPage({super.key, this.controller, this.onScanCompleted});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  static const String _modelAssetPath = 'assets/models/mangroveModel.tflite';
  static const double _defaultMetersPerPixel = 0.003;
  static const double _trunkConfidenceThreshold = 0.55;
  static const double _rootConfidenceThreshold = 0.55;
  static const double _trunkGuideYFraction = 0.6;
  static const List<String> _instanceClassLabels = [
    'mangrove_root',
    'mangrove_trunk',
  ];
  static const int _treeClassIndex = 1;
  static const int _rootClassIndex = 0;
  static const List<String> _maskClassLabels = [
    'mangrove_root',
    'mangrove_trunk',
  ];

  CameraController? _cameraController;
  Interpreter? _interpreter;
  IsolateInterpreter? _isolateInterpreter;
  List<int> _inputShape = const [];
  List<Tensor> _outputTensors = const [];
  TensorType? _inputType;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isModelReady = false;
  bool _isCapturing = false;
  String? _cameraError;
  String? _modelInitError;
  int _lastShutterSignal = 0;
  final GlobalKey _frameGuideInnerKey = GlobalKey();
  Rect? _lastFrameRectInViewport;
  Size? _lastViewportSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?.addListener(_handleExternalShutter);
    _lastShutterSignal = widget.controller?.shutterSignal ?? 0;
    _initSegmentationInterpreter();
    _initCamera();
  }

  @override
  void didUpdateWidget(covariant ScannerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    oldWidget.controller?.removeListener(_handleExternalShutter);
    widget.controller?.addListener(_handleExternalShutter);
    _lastShutterSignal = widget.controller?.shutterSignal ?? 0;
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleExternalShutter);
    WidgetsBinding.instance.removeObserver(this);
    if (_isolateInterpreter != null) {
      unawaited(_isolateInterpreter!.close());
      _isolateInterpreter = null;
    }
    _interpreter?.close();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _cameraError = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
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
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      await _configureCameraForFastCapture(controller);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _cameraController?.dispose();
      _cameraController = controller;
      setState(() => _isInitializing = false);
    } on CameraException catch (e) {
      setState(() {
        _cameraError = 'Camera error: ${e.description ?? e.code}';
        _isInitializing = false;
      });
    } catch (_) {
      setState(() {
        _cameraError = 'Unable to initialize camera.';
        _isInitializing = false;
      });
    }
  }

  void _handleExternalShutter() {
    final controller = widget.controller;
    if (controller == null || controller.shutterSignal == _lastShutterSignal) {
      return;
    }

    _lastShutterSignal = controller.shutterSignal;
    _captureShutter();
  }

  Future<void> _configureCameraForFastCapture(
    CameraController controller,
  ) async {
    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {
      // Ignore if flash control is unavailable on this device.
    }
    try {
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {
      // Ignore if focus lock is unavailable on this device.
    }
    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {
      // Ignore if exposure control is unavailable on this device.
    }
  }

  Future<void> _initSegmentationInterpreter() async {
    setState(() {
      _isModelReady = false;
      _modelInitError = null;
    });

    try {
      final options = InterpreterOptions()..threads = 2;
      if (_isolateInterpreter != null) {
        await _isolateInterpreter!.close();
        _isolateInterpreter = null;
      }
      _interpreter?.close();
      final interpreter = await Interpreter.fromAsset(
        _modelAssetPath,
        options: options,
      );
      IsolateInterpreter? isolateInterpreter;
      try {
        isolateInterpreter = await IsolateInterpreter.create(
          address: interpreter.address,
        );
      } catch (e) {
        debugPrint('Isolate interpreter init failed: $e');
      }
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensors = interpreter.getOutputTensors();
      if (inputTensor.shape.length != 4) {
        throw StateError('Expected 4D input tensor, got ${inputTensor.shape}');
      }

      _interpreter = interpreter;
      _isolateInterpreter = isolateInterpreter;
      _inputShape = inputTensor.shape;
      _inputType = inputTensor.type;
      _outputTensors = outputTensors;
      _logModelSignature(inputTensor, outputTensors);
      if (!mounted) return;
      setState(() {
        _isModelReady = true;
        _modelInitError = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      debugPrint(
        'Segmentation interpreter init failed: ${e.code} ${e.message}',
      );
      setState(() {
        _isModelReady = false;
        _modelInitError = _compactModelError(e.message);
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Segmentation interpreter init failed: $e');
      setState(() {
        _isModelReady = false;
        _modelInitError = _compactModelError(e.toString());
      });
    }
  }

  Future<void> _runModelInferenceOnCapture(String imagePath) async {
    if (_interpreter == null || !_isModelReady) {
      await _initSegmentationInterpreter();
    }

    if (_interpreter == null) {
      final message = _modelInitError == null
          ? 'Model not ready.'
          : 'Model not ready: $_modelInitError';
      _showTopNotification(message);
      return;
    }

    try {
      final result = await _inferTreeFromImagePath(imagePath);
      if (result == null) {
        _showTopNotification(
          'No mangrove tree and roots detected. Try recapturing with roots visible.',
        );
        return;
      }

      widget.controller?.setLatestMeasuredTree(
        tree: result.tree,
        metersPerPixel: result.metersPerPixel,
        capturedImagePath: imagePath,
        rootMaskBytes: result.rootMaskBytes,
        rootMaskWidth: result.rootMaskWidth,
        rootMaskHeight: result.rootMaskHeight,
        trunkMaskBytes: result.trunkMaskBytes,
        trunkMaskWidth: result.trunkMaskWidth,
        trunkMaskHeight: result.trunkMaskHeight,
      );
    } on PlatformException catch (e) {
      debugPrint('Model inference failed: ${e.code} ${e.message}');
      final errorMessage = _compactModelError(e.message);
      _showTopNotification('Model inference failed: $errorMessage');
    } catch (e) {
      debugPrint('Model inference failed: $e');
      _showTopNotification(
        'Model inference failed: ${_compactModelError(e.toString())}',
      );
    }
  }

  String _compactModelError(String? message) {
    if (message == null || message.trim().isEmpty) return 'Unknown error';
    final normalized = message.replaceAll('\n', ' ').trim();
    if (normalized.length <= 80) return normalized;
    return '${normalized.substring(0, 77)}...';
  }

  void _logModelSignature(Tensor inputTensor, List<Tensor> outputTensors) {
    debugPrint(
      'Model signature: input name=${inputTensor.name} shape=${inputTensor.shape} type=${inputTensor.type}',
    );
    debugPrint('Model labels (instance): ${_instanceClassLabels.join(', ')}');
    debugPrint('Model labels (mask): ${_maskClassLabels.join(', ')}');
    for (var i = 0; i < outputTensors.length; i++) {
      final tensor = outputTensors[i];
      debugPrint(
        'Model signature: output[$i] name=${tensor.name} shape=${tensor.shape} type=${tensor.type}',
      );
    }
  }

  Future<_InferenceResult?> _inferTreeFromImagePath(String imagePath) async {
    final interpreter = _interpreter;
    if (interpreter == null) return null;
    final isolateInterpreter = _isolateInterpreter;

    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw StateError('Unable to decode captured image.');
    }
    final metersPerPixel = _estimateMetersPerPixelFromExif(
      bytes,
      sourceWidth: image.width,
    );

    final input = _createModelInput(image);
    final outputs = <int, Object>{};
    for (var i = 0; i < _outputTensors.length; i++) {
      final tensor = _outputTensors[i];
      outputs[i] = _createTensorBuffer(tensor.shape, tensor.type);
    }

    if (isolateInterpreter != null) {
      await isolateInterpreter.runForMultipleInputs([input], outputs);
    } else {
      interpreter.runForMultipleInputs([input], outputs);
    }
    final extracted = _extractTreeFromOutputs(outputs);
    if (extracted == null) return null;
    return _InferenceResult(
      tree: extracted.tree,
      metersPerPixel: metersPerPixel,
      rootMaskBytes: extracted.rootMaskBytes,
      rootMaskWidth: extracted.rootMaskWidth,
      rootMaskHeight: extracted.rootMaskHeight,
      trunkMaskBytes: extracted.trunkMaskBytes,
      trunkMaskWidth: extracted.trunkMaskWidth,
      trunkMaskHeight: extracted.trunkMaskHeight,
    );
  }

  Object _createModelInput(img.Image image) {
    if (_inputShape.length != 4 || _inputType == null) {
      throw StateError('Unsupported input tensor configuration: $_inputShape');
    }

    final isNhwc = _inputShape[3] == 3;
    final isNchw = _inputShape[1] == 3;
    if (!isNhwc && !isNchw) {
      throw StateError('Expected 3-channel input, got $_inputShape');
    }

    final height = isNhwc ? _inputShape[1] : _inputShape[2];
    final width = isNhwc ? _inputShape[2] : _inputShape[3];
    final resized = img.copyResize(image, width: width, height: height);
    final isFloat = _inputType == TensorType.float32;

    if (isNhwc) {
      return [
        List.generate(height, (y) {
          return List.generate(width, (x) {
            final pixel = resized.getPixel(x, y);
            if (isFloat) {
              return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
            }
            return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
          });
        }),
      ];
    }

    return [
      List.generate(3, (channel) {
        return List.generate(height, (y) {
          return List.generate(width, (x) {
            final pixel = resized.getPixel(x, y);
            final value = switch (channel) {
              0 => pixel.r,
              1 => pixel.g,
              _ => pixel.b,
            };
            return isFloat ? value / 255.0 : value.toInt();
          });
        });
      }),
    ];
  }

  double _estimateMetersPerPixelFromExif(
    Uint8List bytes, {
    required int sourceWidth,
  }) {
    try {
      final exif = img.decodeJpgExif(bytes);
      if (exif == null) return _defaultMetersPerPixel;

      final focalLength = exif.getTag(0x920A)?.toDouble();
      final subjectDistance = exif.getTag(0x9206)?.toDouble();
      final focalPlaneXResolution = exif.getTag(0xA20E)?.toDouble();
      final focalPlaneResolutionUnit = exif.getTag(0xA210)?.toInt();

      if (focalLength == null ||
          focalPlaneXResolution == null ||
          focalPlaneResolutionUnit == null ||
          subjectDistance == null ||
          focalLength <= 0 ||
          focalPlaneXResolution <= 0 ||
          subjectDistance <= 0) {
        return _defaultMetersPerPixel;
      }

      final unitMm = switch (focalPlaneResolutionUnit) {
        2 => 25.4, // inch
        3 => 10.0, // cm
        _ => null,
      };
      if (unitMm == null) return _defaultMetersPerPixel;

      final pixelPitchMm = unitMm / focalPlaneXResolution;
      final isNhwc = _inputShape[3] == 3;
      final modelWidth = isNhwc ? _inputShape[2] : _inputShape[3];
      if (modelWidth <= 0 || sourceWidth <= 0) return _defaultMetersPerPixel;
      final scale = sourceWidth / modelWidth;

      final metersPerPixel = subjectDistance * (pixelPitchMm / focalLength);
      final adjusted = metersPerPixel * scale;
      if (!adjusted.isFinite || adjusted <= 0) return _defaultMetersPerPixel;
      return adjusted.clamp(0.00005, 0.05);
    } catch (_) {
      return _defaultMetersPerPixel;
    }
  }

  Object _createTensorBuffer(List<int> shape, TensorType type) {
    if (shape.isEmpty) {
      if (type == TensorType.float32 || type == TensorType.float16) return 0.0;
      return 0;
    }
    final rest = shape.sublist(1);
    return List.generate(
      shape.first,
      (_) => _createTensorBuffer(rest, type),
      growable: false,
    );
  }

  _ExtractedTree? _extractTreeFromOutputs(Map<int, Object> outputs) {
    for (var i = 0; i < _outputTensors.length; i++) {
      final tensor = _outputTensors[i];
      final shape = tensor.shape;
      if (shape.length != 4 || shape.first != 1) continue;

      final parsed = _parseMasksFromTensor(outputs[i], shape);
      if (parsed == null) continue;
      final tree = _buildTreeFromMasks(parsed);
      if (tree != null) {
        final maskHeight = parsed.rootMask.length;
        final maskWidth = maskHeight == 0 ? 0 : parsed.rootMask.first.length;
        final maskBytes = maskWidth > 0 && maskHeight > 0
            ? _packMaskToBytes(parsed.rootMask)
            : null;
        final trunkBytes = maskWidth > 0 && maskHeight > 0
            ? _packMaskToBytes(parsed.treeMask)
            : null;
        return _ExtractedTree(
          tree: tree,
          rootMaskBytes: maskBytes,
          rootMaskWidth: maskWidth > 0 ? maskWidth : null,
          rootMaskHeight: maskHeight > 0 ? maskHeight : null,
          trunkMaskBytes: trunkBytes,
          trunkMaskWidth: maskWidth > 0 ? maskWidth : null,
          trunkMaskHeight: maskHeight > 0 ? maskHeight : null,
        );
      }
    }

    final fromInstances = _extractTreeFromInstanceOutputs(outputs);
    if (fromInstances != null) {
      return _ExtractedTree(tree: fromInstances);
    }

    final shapes = _outputTensors.map((t) => t.shape).join(', ');
    debugPrint('Unsupported output tensors for parser: $shapes');
    return null;
  }

  Uint8List _packMaskToBytes(List<List<bool>> mask) {
    final height = mask.length;
    if (height == 0) return Uint8List(0);
    final width = mask.first.length;
    if (width == 0) return Uint8List(0);
    final total = width * height;
    final bytes = Uint8List((total + 7) >> 3);
    var byteIndex = 0;
    var bitIndex = 0;
    var current = 0;
    for (var y = 0; y < height; y++) {
      final row = mask[y];
      for (var x = 0; x < width; x++) {
        if (row[x]) {
          current |= 1 << (7 - bitIndex);
        }
        bitIndex++;
        if (bitIndex == 8) {
          bytes[byteIndex] = current;
          byteIndex++;
          bitIndex = 0;
          current = 0;
        }
      }
    }
    if (bitIndex != 0 && byteIndex < bytes.length) {
      bytes[byteIndex] = current;
    }
    return bytes;
  }

  MangroveTree? _extractTreeFromInstanceOutputs(Map<int, Object> outputs) {
    _InstanceOutput? best;
    for (var i = 0; i < _outputTensors.length; i++) {
      final shape = _outputTensors[i].shape;
      if (shape.length != 3 || shape.first != 1) continue;
      final parsed = _parseInstanceOutput(outputs[i], shape);
      if (parsed == null) continue;
      if (best == null || parsed.predictions > best.predictions) {
        best = parsed;
      }
    }
    if (best == null) return null;

    final classes = _instanceClassLabels.length;
    final channels = best.channels;
    if (channels < 4 + classes) return null;

    final layout = _inferInstanceLayout(channels, classes);
    if (layout == null) {
      debugPrint(
        'Unsupported instance layout: channels=$channels classes=$classes (labels=${_instanceClassLabels.join(', ')})',
      );
      return null;
    }
    final hasObjectness = layout.hasObjectness;
    final classStart = layout.classStart;
    final treeScoreIndex = classStart + _treeClassIndex;
    final rootScoreIndex = classStart + _rootClassIndex;
    if (rootScoreIndex >= channels) return null;

    final modelHeight = _inputShape[3] == 3 ? _inputShape[1] : _inputShape[2];
    final modelWidth = _inputShape[3] == 3 ? _inputShape[2] : _inputShape[3];
    final guideLineY = modelHeight * _trunkGuideYFraction;

    final treeCandidates = <_Detection>[];
    final rootCandidates = <_Detection>[];
    var maxBoxValue = 0.0;
    for (var p = 0; p < best.predictions; p++) {
      final cx = best.valueAt(p, 0).toDouble();
      final cy = best.valueAt(p, 1).toDouble();
      final w = best.valueAt(p, 2).abs().toDouble();
      final h = best.valueAt(p, 3).abs().toDouble();
      if (w <= 0 || h <= 0) continue;

      final treeScore = _toProbability(
        best.valueAt(p, treeScoreIndex).toDouble(),
      );
      final rootScore = _toProbability(
        best.valueAt(p, rootScoreIndex).toDouble(),
      );
      final objectness = hasObjectness
          ? _toProbability(best.valueAt(p, 4).toDouble())
          : 1.0;
      final treeConfidence = objectness * treeScore;
      final rootConfidence = objectness * rootScore;
      if (treeConfidence < _trunkConfidenceThreshold &&
          rootConfidence < _rootConfidenceThreshold) {
        continue;
      }

      final left = cx - (w / 2);
      final top = cy - (h / 2);
      final right = cx + (w / 2);
      final bottom = cy + (h / 2);

      maxBoxValue = math.max(maxBoxValue, math.max(right.abs(), bottom.abs()));
      if (treeConfidence >= _trunkConfidenceThreshold) {
        treeCandidates.add(
          _Detection(
            classId: 0,
            score: treeConfidence,
            left: left,
            top: top,
            right: right,
            bottom: bottom,
          ),
        );
      }
      if (rootConfidence >= _rootConfidenceThreshold) {
        rootCandidates.add(
          _Detection(
            classId: 1,
            score: rootConfidence,
            left: left,
            top: top,
            right: right,
            bottom: bottom,
          ),
        );
      }
    }
    if (treeCandidates.isEmpty || rootCandidates.isEmpty) return null;

    final normalizedBoxes = maxBoxValue <= 2.0;
    final scaledTrees = treeCandidates
        .map((d) {
          if (!normalizedBoxes) return d;
          return _Detection(
            classId: 0,
            score: d.score,
            left: d.left * modelWidth,
            top: d.top * modelHeight,
            right: d.right * modelWidth,
            bottom: d.bottom * modelHeight,
          );
        })
        .toList(growable: false);
    final scaledRoots = rootCandidates
        .map((d) {
          if (!normalizedBoxes) return d;
          return _Detection(
            classId: 1,
            score: d.score,
            left: d.left * modelWidth,
            top: d.top * modelHeight,
            right: d.right * modelWidth,
            bottom: d.bottom * modelHeight,
          );
        })
        .toList(growable: false);

    final treeDetections = _nms(scaledTrees, 0.45);
    final rootDetections = _nms(scaledRoots, 0.55);
    if (treeDetections.isEmpty || rootDetections.isEmpty) return null;

    final trunk = treeDetections.first;
    final treeWidth = trunk.width.clamp(1.0, 4000.0).toDouble();
    final trunkCenterX = trunk.centerX;
    final associatedRoots = _rootsForSelectedTree(
      rootDetections,
      treeDetections,
      trunk,
    );
    final measuredTrunkWidth = (treeWidth * 0.22).clamp(1.0, 4000.0).toDouble();
    final filteredRoots = _filterRootsByTreeBounds(
      associatedRoots,
      trunk,
      measuredTrunkWidth,
      guideLineY,
    );
    final roots = filteredRoots
        .take(96)
        .map((root) {
          final dx = root.centerX - trunkCenterX;
          final dy = root.centerY - trunk.bottom;
          final rootLength = root.width.clamp(4.0, 4000.0).toDouble();
          return Root(
            position: Offset(dx, dy),
            length: rootLength,
            angle: dx < 0 ? math.pi : 0.0,
            normalizedLeft: (root.left / modelWidth).clamp(0.0, 1.0),
            normalizedTop: (root.top / modelHeight).clamp(0.0, 1.0),
            normalizedRight: (root.right / modelWidth).clamp(0.0, 1.0),
            normalizedBottom: (root.bottom / modelHeight).clamp(0.0, 1.0),
          );
        })
        .toList(growable: false);
    if (roots.isEmpty) return null;

    var branchY = trunk.bottom;
    for (final root in filteredRoots) {
      if (root.top < branchY) branchY = root.top;
    }
    branchY = branchY.clamp(trunk.top, trunk.bottom);

    final halfWidth = measuredTrunkWidth / 2.0;
    final startX = ((trunkCenterX - halfWidth) / modelWidth).clamp(0.0, 1.0);
    final endX = ((trunkCenterX + halfWidth) / modelWidth).clamp(0.0, 1.0);
    final trunkMeasurement = TrunkMeasurement(
      startX: startX,
      endX: endX,
      y: (branchY / modelHeight).clamp(0.0, 1.0),
      isEstimated: true,
    );
    final treeBounds = TreeBounds(
      left: (trunk.left / modelWidth).clamp(0.0, 1.0),
      top: (trunk.top / modelHeight).clamp(0.0, 1.0),
      right: (trunk.right / modelWidth).clamp(0.0, 1.0),
      bottom: (trunk.bottom / modelHeight).clamp(0.0, 1.0),
    );

    return MangroveTree(
      trunkWidthAtBranchPoint: measuredTrunkWidth,
      roots: roots,
      trunkMeasurement: trunkMeasurement,
      treeBounds: treeBounds,
    );
  }

  _InstanceOutput? _parseInstanceOutput(Object? output, List<int> shape) {
    if (output is! List || output.isEmpty) return null;
    final first = output.first;
    if (first is! List || first.isEmpty) return null;

    final a = shape[1];
    final b = shape[2];
    final channelFirst = b > a;
    final channels = channelFirst ? a : b;
    final predictions = channelFirst ? b : a;
    if (channels < 6 || predictions < 1) return null;

    return _InstanceOutput(
      data: first,
      channels: channels,
      predictions: predictions,
      channelFirst: channelFirst,
    );
  }

  _InstanceLayout? _inferInstanceLayout(int channels, int classes) {
    final noMaskNoObj = 4 + classes;
    final objNoMask = 5 + classes;
    final noObjMask = 4 + classes + 32;
    final objMask = 5 + classes + 32;

    if (channels == noMaskNoObj) {
      return const _InstanceLayout(hasObjectness: false, classStart: 4);
    }
    if (channels == objNoMask) {
      return const _InstanceLayout(hasObjectness: true, classStart: 5);
    }
    if (channels == noObjMask) {
      return const _InstanceLayout(hasObjectness: false, classStart: 4);
    }
    if (channels == objMask) {
      return const _InstanceLayout(hasObjectness: true, classStart: 5);
    }

    final hasObjectness = channels > (4 + classes + 32);
    final classStart = hasObjectness ? 5 : 4;
    debugPrint(
      'Falling back to heuristic instance layout: channels=$channels classes=$classes '
      'hasObjectness=$hasObjectness classStart=$classStart',
    );
    return _InstanceLayout(
      hasObjectness: hasObjectness,
      classStart: classStart,
    );
  }

  List<_Detection> _nms(List<_Detection> detections, double iouThreshold) {
    if (detections.isEmpty) return const [];
    final sorted = [...detections]..sort((a, b) => b.score.compareTo(a.score));
    final kept = <_Detection>[];
    for (final det in sorted) {
      var overlaps = false;
      for (final chosen in kept) {
        if (_iou(det, chosen) > iouThreshold) {
          overlaps = true;
          break;
        }
      }
      if (!overlaps) kept.add(det);
    }
    return kept;
  }

  double _iou(_Detection a, _Detection b) {
    final interLeft = math.max(a.left, b.left);
    final interTop = math.max(a.top, b.top);
    final interRight = math.min(a.right, b.right);
    final interBottom = math.min(a.bottom, b.bottom);
    final interW = math.max(0.0, interRight - interLeft);
    final interH = math.max(0.0, interBottom - interTop);
    final interArea = interW * interH;
    if (interArea <= 0) return 0;
    final union = a.area + b.area - interArea;
    if (union <= 0) return 0;
    return interArea / union;
  }

  double _toProbability(double value) {
    if (value >= 0 && value <= 1) return value;
    if (value > 20) return 1;
    if (value < -20) return 0;
    return 1 / (1 + math.exp(-value));
  }

  _ParsedMasks? _parseMasksFromTensor(Object? output, List<int> shape) {
    if (output is! List) return null;

    final channelLast = shape[3] >= 2 && shape[3] <= 8;
    final channelFirst = shape[1] >= 2 && shape[1] <= 8;
    if (!channelLast && !channelFirst) return null;

    final height = channelLast ? shape[1] : shape[2];
    final width = channelLast ? shape[2] : shape[3];
    final classes = channelLast ? shape[3] : shape[1];
    if (classes < 2) return null;
    if (classes != 2 && classes != 3) {
      debugPrint(
        'Unsupported mask classes: $classes. Expected 2 (root=0, trunk=1) or 3 (root=0, trunk=1, extra/background).',
      );
      return null;
    }

    // Fixed class mapping: 0 = mangrove_root, 1 = mangrove_trunk.
    const rootClass = 0;
    const trunkClass = 1;
    if (trunkClass >= classes) return null;

    final treeMask = List.generate(
      height,
      (_) => List<bool>.filled(width, false, growable: false),
      growable: false,
    );
    final rootMask = List.generate(
      height,
      (_) => List<bool>.filled(width, false, growable: false),
      growable: false,
    );

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var bestClass = 0;
        var bestScore = -double.infinity;
        for (var c = 0; c < classes; c++) {
          final score = channelLast
              ? ((((output[0] as List)[y] as List)[x] as List)[c] as num)
                    .toDouble()
              : ((((output[0] as List)[c] as List)[y] as List)[x] as num)
                    .toDouble();
          if (score > bestScore) {
            bestScore = score;
            bestClass = c;
          }
        }
        if (bestClass == trunkClass) treeMask[y][x] = true;
        if (bestClass == rootClass) rootMask[y][x] = true;
      }
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (treeMask[y][x]) rootMask[y][x] = false;
      }
    }

    return _ParsedMasks(treeMask: treeMask, rootMask: rootMask);
  }

  MangroveTree? _buildTreeFromMasks(_ParsedMasks masks) {
    final treeBounds = _findMaskBounds(masks.treeMask);
    if (treeBounds == null) return null;

    final components = _extractRootComponents(masks.rootMask);
    if (components.isEmpty) return null;
    final activeComponents = _filterRootComponentsByTreeBounds(
      components,
      treeBounds,
    );
    final maskHeight = masks.rootMask.length;
    final maskWidth = masks.rootMask.first.length;
    final guideLineY = maskHeight * _trunkGuideYFraction;
    var branchY = activeComponents.first.minY.toInt().clamp(
      treeBounds.minY,
      treeBounds.maxY,
    );
    for (final component in activeComponents) {
      final minY = component.minY.toInt();
      if (minY < branchY) branchY = minY;
    }
    branchY = math.max(branchY, guideLineY.toInt());
    final rowSpan = _findNearestRowSpan(
      masks.treeMask,
      branchY,
      treeBounds.minY,
      treeBounds.maxY,
      6,
    );

    final trunkWidth = rowSpan?.width.toDouble() ?? treeBounds.width.toDouble();
    final trunkCenterX = rowSpan?.centerX ?? treeBounds.centerX;
    final spanMinX = rowSpan?.minX ?? treeBounds.minX;
    final spanMaxX = rowSpan?.maxX ?? treeBounds.maxX;

    final corridorHalfWidth = math.min(
      treeBounds.width * 0.35,
      trunkWidth * 3.5,
    );
    final corridorMinX = trunkCenterX - corridorHalfWidth;
    final corridorMaxX = trunkCenterX + corridorHalfWidth;
    final corridorComponents = activeComponents
        .where((component) {
          final cx = component.centerX;
          return cx >= corridorMinX &&
              cx <= corridorMaxX &&
              component.minY >= math.max(branchY, guideLineY);
        })
        .toList(growable: false);
    final usableComponents = corridorComponents.isEmpty
        ? activeComponents
        : corridorComponents;
    var adjustedBranchY = usableComponents.first.minY.toInt().clamp(
      treeBounds.minY,
      treeBounds.maxY,
    );
    for (final component in usableComponents) {
      final minY = component.minY.toInt();
      if (minY < adjustedBranchY) adjustedBranchY = minY;
    }

    final roots = usableComponents
        .map((component) {
          final dx = component.centerX - trunkCenterX;
          final dy = component.centerY - adjustedBranchY;
          final length = (component.width * 0.7).clamp(4.0, 4000.0).toDouble();
          return Root(
            position: Offset(dx, dy),
            length: length,
            angle: dx < 0 ? math.pi : 0.0,
            normalizedLeft: (component.minX / maskWidth).clamp(0.0, 1.0),
            normalizedTop: (component.minY / maskHeight).clamp(0.0, 1.0),
            normalizedRight: (component.maxX / maskWidth).clamp(0.0, 1.0),
            normalizedBottom: (component.maxY / maskHeight).clamp(0.0, 1.0),
          );
        })
        .toList(growable: false);

    final trunkMeasurement = TrunkMeasurement(
      startX: (spanMinX / maskWidth).clamp(0.0, 1.0),
      endX: (spanMaxX / maskWidth).clamp(0.0, 1.0),
      y: (adjustedBranchY / maskHeight).clamp(0.0, 1.0),
      isEstimated: false,
    );
    final treeBoundsNormalized = TreeBounds(
      left: (treeBounds.minX / maskWidth).clamp(0.0, 1.0),
      top: (treeBounds.minY / maskHeight).clamp(0.0, 1.0),
      right: (treeBounds.maxX / maskWidth).clamp(0.0, 1.0),
      bottom: (treeBounds.maxY / maskHeight).clamp(0.0, 1.0),
    );

    return MangroveTree(
      trunkWidthAtBranchPoint: trunkWidth.clamp(1.0, 4000.0).toDouble(),
      roots: roots,
      trunkMeasurement: trunkMeasurement,
      treeBounds: treeBoundsNormalized,
    );
  }

  _MaskBounds? _findMaskBounds(List<List<bool>> mask) {
    var minX = 1 << 30;
    var minY = 1 << 30;
    var maxX = -1;
    var maxY = -1;

    for (var y = 0; y < mask.length; y++) {
      for (var x = 0; x < mask[y].length; x++) {
        if (!mask[y][x]) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    if (maxX < 0 || maxY < 0) return null;
    return _MaskBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  _RowSpan? _findRowSpanAt(List<List<bool>> mask, int y) {
    if (y < 0 || y >= mask.length) return null;
    int rowMinX = -1;
    int rowMaxX = -1;
    for (var x = 0; x < mask[y].length; x++) {
      if (!mask[y][x]) continue;
      rowMinX = rowMinX < 0 ? x : math.min(rowMinX, x);
      rowMaxX = math.max(rowMaxX, x);
    }
    if (rowMinX < 0 || rowMaxX < rowMinX) return null;
    return _RowSpan(
      minX: rowMinX,
      maxX: rowMaxX,
      centerX: (rowMinX + rowMaxX) / 2.0,
    );
  }

  _RowSpan? _findNearestRowSpan(
    List<List<bool>> mask,
    int startY,
    int minY,
    int maxY,
    int maxOffset,
  ) {
    for (var offset = 0; offset <= maxOffset; offset++) {
      final upY = startY - offset;
      if (upY >= minY) {
        final span = _findRowSpanAt(mask, upY);
        if (span != null) return span;
      }
      final downY = startY + offset;
      if (downY <= maxY) {
        final span = _findRowSpanAt(mask, downY);
        if (span != null) return span;
      }
    }
    return null;
  }

  List<_Detection> _filterRootsByTreeBounds(
    List<_Detection> roots,
    _Detection tree,
    double measuredTrunkWidth,
    double guideLineY,
  ) {
    if (roots.isEmpty) return roots;
    final corridorHalfWidth = math.min(
      tree.width * 0.35,
      measuredTrunkWidth * 3.5,
    );
    final minX = tree.centerX - corridorHalfWidth;
    final maxX = tree.centerX + corridorHalfWidth;
    final minY = math.max(tree.bottom + (tree.height * 0.02), guideLineY);
    final filtered = roots
        .where((root) {
          if (_overlapRatio(root, tree) > 0.25) return false;
          final cx = root.centerX;
          final cy = root.centerY;
          return cx >= minX && cx <= maxX && cy >= minY;
        })
        .toList(growable: false);
    return filtered.isEmpty ? roots : filtered;
  }

  List<_RootComponent> _filterRootComponentsByTreeBounds(
    List<_RootComponent> components,
    _MaskBounds treeBounds,
  ) {
    if (components.isEmpty) return components;
    final marginX = treeBounds.width * 0.18;
    final minX = treeBounds.minX - marginX;
    final maxX = treeBounds.maxX + marginX;
    final marginY = treeBounds.height * 0.12;
    final minY = treeBounds.maxY - marginY;
    final filtered = components
        .where((component) {
          final cx = component.centerX;
          final cy = component.centerY;
          return cx >= minX && cx <= maxX && cy >= minY;
        })
        .toList(growable: false);
    return filtered.isEmpty ? components : filtered;
  }

  double _overlapRatio(_Detection a, _Detection b) {
    final interLeft = math.max(a.left, b.left);
    final interTop = math.max(a.top, b.top);
    final interRight = math.min(a.right, b.right);
    final interBottom = math.min(a.bottom, b.bottom);
    final interW = math.max(0.0, interRight - interLeft);
    final interH = math.max(0.0, interBottom - interTop);
    final interArea = interW * interH;
    if (interArea <= 0) return 0;
    if (a.area <= 0) return 0;
    return interArea / a.area;
  }

  List<_Detection> _rootsForSelectedTree(
    List<_Detection> roots,
    List<_Detection> trees,
    _Detection selectedTree,
  ) {
    if (roots.isEmpty || trees.length <= 1) return roots;
    final assigned = <_Detection>[];
    for (final root in roots) {
      _Detection nearest = trees.first;
      var nearestDistance = (root.centerX - nearest.centerX).abs();
      for (final tree in trees.skip(1)) {
        final distance = (root.centerX - tree.centerX).abs();
        if (distance < nearestDistance) {
          nearest = tree;
          nearestDistance = distance;
        }
      }
      if (identical(nearest, selectedTree)) {
        assigned.add(root);
      }
    }
    return assigned.isEmpty ? roots : assigned;
  }

  List<_RootComponent> _extractRootComponents(List<List<bool>> rootMask) {
    if (rootMask.isEmpty || rootMask.first.isEmpty) return const [];
    final h = rootMask.length;
    final w = rootMask.first.length;
    final visited = List.generate(
      h,
      (_) => List<bool>.filled(w, false, growable: false),
      growable: false,
    );
    final components = <_RootComponent>[];

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!rootMask[y][x] || visited[y][x]) continue;

        final queue = <_Point>[_Point(x, y)];
        visited[y][x] = true;
        var qIndex = 0;

        var pixels = 0;
        var sumX = 0.0;
        var sumY = 0.0;
        var minX = x;
        var maxX = x;
        var minY = y;
        var maxY = y;

        while (qIndex < queue.length) {
          final point = queue[qIndex++];
          pixels++;
          sumX += point.x;
          sumY += point.y;
          if (point.x < minX) minX = point.x;
          if (point.x > maxX) maxX = point.x;
          if (point.y < minY) minY = point.y;
          if (point.y > maxY) maxY = point.y;

          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nx = point.x + dx;
              final ny = point.y + dy;
              if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
              if (visited[ny][nx] || !rootMask[ny][nx]) continue;
              visited[ny][nx] = true;
              queue.add(_Point(nx, ny));
            }
          }
        }

        if (pixels < 12) continue;
        components.add(
          _RootComponent(
            centerX: sumX / pixels,
            centerY: sumY / pixels,
            width: (maxX - minX + 1).toDouble(),
            area: pixels,
            minX: minX.toDouble(),
            minY: minY.toDouble(),
            maxX: maxX.toDouble(),
            maxY: maxY.toDouble(),
          ),
        );
      }
    }

    components.sort((a, b) => b.area.compareTo(a.area));
    return components.take(48).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
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

    if (_cameraError != null) {
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
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  _cameraError!,
                  style: const TextStyle(color: antiFlashWhite),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: caribbeanGreen,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: richBlack),
                  ),
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
        ],
      ),
    );
  }

  Widget _buildScannerHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatusChip(
                  icon: Icons.blur_on_rounded,
                  label: _isModelReady
                      ? 'Model Ready'
                      : (_modelInitError == null
                            ? 'Model Loading'
                            : 'Model Error'),
                  glow: caribbeanGreen,
                ),
                const Spacer(),
                _buildStatusChip(
                  icon: _isCapturing ? Icons.camera : Icons.check_circle,
                  label: _isCapturing ? 'Analyzing' : 'Ready',
                  glow: _isCapturing ? const Color(0xFFFFA34D) : caribbeanGreen,
                  trailing: _isCapturing
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
            const Spacer(),
            _buildFrameGuide(),
            const Spacer(),
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

  Widget _buildFrameGuide() {
    final size = MediaQuery.sizeOf(context);
    final frameWidth = (size.width * 0.82).clamp(280.0, 340.0).toDouble();
    final frameHeight = (size.height * 0.5).clamp(320.0, 420.0).toDouble();
    final innerWidth = (frameWidth - 30).clamp(250.0, 305.0).toDouble();
    final innerHeight = (frameHeight - 28).clamp(290.0, 385.0).toDouble();
    return SizedBox(
      width: frameWidth,
      height: frameHeight,
      child: Stack(
        children: [
          Align(
            child: Container(
              key: _frameGuideInnerKey,
              width: innerWidth,
              height: innerHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: antiFlashWhite.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: _frameCorner(top: true, left: true),
          ),
          Align(
            alignment: Alignment.topRight,
            child: _frameCorner(top: true, left: false),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: _frameCorner(top: false, left: true),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: _frameCorner(top: false, left: false),
          ),
        ],
      ),
    );
  }

  Widget _frameCorner({required bool top, required bool left}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? BorderSide(
                  color: caribbeanGreen.withValues(alpha: 0.95),
                  width: 3,
                )
              : BorderSide.none,
          bottom: !top
              ? BorderSide(
                  color: caribbeanGreen.withValues(alpha: 0.95),
                  width: 3,
                )
              : BorderSide.none,
          left: left
              ? BorderSide(
                  color: caribbeanGreen.withValues(alpha: 0.95),
                  width: 3,
                )
              : BorderSide.none,
          right: !left
              ? BorderSide(
                  color: caribbeanGreen.withValues(alpha: 0.95),
                  width: 3,
                )
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildGuidancePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: darkGreen.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: caribbeanGreen.withValues(alpha: 0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Field Guidance',
            style: TextStyle(
              color: antiFlashWhite,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '1) Keep the trunk base fully visible.\n2) Hold steady and tap the center shutter button.\n3) Re-capture if roots are partially blocked.',
            style: TextStyle(color: antiFlashWhite, fontSize: 12, height: 1.4),
          ),
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

  Future<void> _captureShutter() async {
    final controller = _cameraController;
    if (_isCapturing || controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isTakingPicture) return;

    setState(() => _isCapturing = true);
    try {
      final picture = await controller.takePicture();
      final croppedImagePath = await _cropCapturedImageToFrame(picture.path);
      if (!mounted) return;
      await _runModelInferenceOnCapture(croppedImagePath);
      if (!mounted) return;
      widget.onScanCompleted?.call();
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

  Future<String> _cropCapturedImageToFrame(String imagePath) async {
    final controller = _cameraController;
    if (controller == null || !mounted) return imagePath;

    final previewSize = controller.value.previewSize;
    if (previewSize == null) return imagePath;

    final frameContext = _frameGuideInnerKey.currentContext;
    final rootRenderObject = context.findRenderObject();
    final frameRenderObject = frameContext?.findRenderObject();

    Rect? frameRectInViewport;
    Size? viewportSize;
    if (rootRenderObject is RenderBox && frameRenderObject is RenderBox) {
      final frameGlobalTopLeft = frameRenderObject.localToGlobal(Offset.zero);
      final rootGlobalTopLeft = rootRenderObject.localToGlobal(Offset.zero);
      frameRectInViewport =
          (frameGlobalTopLeft - rootGlobalTopLeft) & frameRenderObject.size;
      viewportSize = rootRenderObject.size;
      _lastFrameRectInViewport = frameRectInViewport;
      _lastViewportSize = viewportSize;
    } else {
      frameRectInViewport = _lastFrameRectInViewport;
      viewportSize = _lastViewportSize;
    }

    if (frameRectInViewport == null || viewportSize == null) {
      return imagePath;
    }
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return imagePath;

    final previewWidth = previewSize.height;
    final previewHeight = previewSize.width;
    if (previewWidth <= 0 || previewHeight <= 0) return imagePath;

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
      return imagePath;
    }

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
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        });

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
                      color: caribbeanGreen.withValues(alpha: 0.35),
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
                        color: caribbeanGreen,
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

class _ParsedMasks {
  final List<List<bool>> treeMask;
  final List<List<bool>> rootMask;

  const _ParsedMasks({required this.treeMask, required this.rootMask});
}

class _MaskBounds {
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  const _MaskBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;

  double get centerX => (minX + maxX) / 2.0;
}

class _RootComponent {
  final double centerX;
  final double centerY;
  final double width;
  final int area;
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const _RootComponent({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.area,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
}

class _Point {
  final int x;
  final int y;

  const _Point(this.x, this.y);
}

class _RowSpan {
  final int minX;
  final int maxX;
  final double centerX;

  const _RowSpan({
    required this.minX,
    required this.maxX,
    required this.centerX,
  });

  int get width => maxX - minX + 1;
}

class _InstanceOutput {
  final List<dynamic> data;
  final int channels;
  final int predictions;
  final bool channelFirst;

  const _InstanceOutput({
    required this.data,
    required this.channels,
    required this.predictions,
    required this.channelFirst,
  });

  num valueAt(int predictionIndex, int channelIndex) {
    if (channelFirst) {
      return ((data[channelIndex] as List)[predictionIndex] as num);
    }
    return ((data[predictionIndex] as List)[channelIndex] as num);
  }
}

class _InstanceLayout {
  final bool hasObjectness;
  final int classStart;

  const _InstanceLayout({
    required this.hasObjectness,
    required this.classStart,
  });
}

class _Detection {
  final int classId;
  final double score;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _Detection({
    required this.classId,
    required this.score,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => (right - left).abs();

  double get height => (bottom - top).abs();

  double get centerX => (left + right) / 2.0;

  double get centerY => (top + bottom) / 2.0;

  double get area => width * height;
}
