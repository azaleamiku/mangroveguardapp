import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/mangrove_tree.dart';

class MangroveDetectionResult {
  final MangroveTree tree;
  final double? predictionConfidence;
  final StabilityAssessment? predictedAssessment;
  final TreeBounds? boundingBox;

  const MangroveDetectionResult({
    required this.tree,
    this.predictionConfidence,
    this.predictedAssessment,
    this.boundingBox,
  });
}

class MangroveDetector {
  static const String _modelAssetPath = 'assets/models/mangroveModel.tflite';
  static const String modelAssetPath = _modelAssetPath;
  /// Model Class Mapping:
  /// 0: high_stability
  /// 1: low_stability
  /// 2: moderate_stability
  static const List<StabilityAssessment> _classOrder = [
    StabilityAssessment.high,
    StabilityAssessment.low,
    StabilityAssessment.moderate,
  ];
  static bool _didLogDebug = false;

  final Interpreter _interpreter;
  final int _inputWidth;
  final int _inputHeight;
  final TensorType _inputType;

  MangroveDetector._(
    this._interpreter,
    this._inputWidth,
    this._inputHeight,
    this._inputType,
  );

  static InterpreterOptions _buildOptions() {
    final options = InterpreterOptions()..threads = 2;
    if (kReleaseMode) {
      options
        ..useNnApiForAndroid = true
        ..useMetalDelegateForIOS = true;
    }
    return options;
  }

  static Future<MangroveDetector> create() async {
    final options = _buildOptions();
    final interpreter = await Interpreter.fromAsset(
      _modelAssetPath,
      options: options,
    );
    final inputTensor = interpreter.getInputTensor(0);
    final shape = inputTensor.shape;
    if (shape.length < 3) {
      interpreter.close();
      throw StateError('Unexpected input tensor shape: $shape');
    }
    final height = shape.length == 4 ? shape[1] : shape[0];
    final width = shape.length == 4 ? shape[2] : shape[1];
    return MangroveDetector._(interpreter, width, height, inputTensor.type);
  }

  static Future<MangroveDetector> createFromBuffer(
    Uint8List modelBytes,
  ) async {
    final options = _buildOptions();
    final interpreter = Interpreter.fromBuffer(
      modelBytes,
      options: options,
    );
    final inputTensor = interpreter.getInputTensor(0);
    final shape = inputTensor.shape;
    if (shape.length < 3) {
      interpreter.close();
      throw StateError('Unexpected input tensor shape: $shape');
    }
    final height = shape.length == 4 ? shape[1] : shape[0];
    final width = shape.length == 4 ? shape[2] : shape[1];
    return MangroveDetector._(interpreter, width, height, inputTensor.type);
  }

  static Future<Uint8List> loadModelBytes() async {
    final data = await rootBundle.load(_modelAssetPath);
    return data.buffer.asUint8List();
  }

  void dispose() {
    _interpreter.close();
  }

  Future<MangroveDetectionResult> detect(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Unable to decode image.');
    }
    final oriented = img.bakeOrientation(decoded);
    return _detectFromImage(oriented);
  }

  Future<MangroveDetectionResult> detectFromImage(img.Image image) async {
    return _detectFromImage(image);
  }

  MangroveDetectionResult _detectFromImage(img.Image image) {
    final resized = img.copyResize(
      image,
      width: _inputWidth,
      height: _inputHeight,
      interpolation: img.Interpolation.average,
    );

    final input = _buildInput(resized);
    final outputs = _allocateOutputBuffers();
    _interpreter.runForMultipleInputs([input], outputs.buffers);

    _logDebugOnce(outputs);

    final detection = _extractBestPrediction(outputs);
    if (detection != null) {
      final assessment = detection.classIndex >= 0 &&
              detection.classIndex < _classOrder.length
          ? _classOrder[detection.classIndex]
          : null;
      final tree = MangroveTree(
        trunkWidthAtBranchPoint:
            (detection.bounds.right - detection.bounds.left).clamp(0.0, 1.0),
        roots: const [],
        treeBounds: detection.bounds,
      );
      return MangroveDetectionResult(
        tree: tree,
        predictionConfidence: detection.confidence,
        predictedAssessment: assessment,
        boundingBox: detection.bounds,
      );
    }

    return MangroveDetectionResult(
      tree: const MangroveTree(trunkWidthAtBranchPoint: 0, roots: []),
    );
  }

  Object _buildInput(img.Image image) {
    if (_inputType == TensorType.float32) {
      final floats = Float32List(_inputWidth * _inputHeight * 3);
      var index = 0;
      final maxValue = image.maxChannelValue;
      for (var y = 0; y < _inputHeight; y++) {
        for (var x = 0; x < _inputWidth; x++) {
          final pixel = image.getPixel(x, y);
          floats[index++] = (pixel.r / maxValue).toDouble();
          floats[index++] = (pixel.g / maxValue).toDouble();
          floats[index++] = (pixel.b / maxValue).toDouble();
        }
      }
      return floats.buffer;
    }

    if (_inputType == TensorType.int8) {
      final params = _interpreter.getInputTensor(0).params;
      final data = Int8List(_inputWidth * _inputHeight * 3);
      var index = 0;
      final maxValue = image.maxChannelValue;
      for (var y = 0; y < _inputHeight; y++) {
        for (var x = 0; x < _inputWidth; x++) {
          final pixel = image.getPixel(x, y);
          final r = (pixel.r / maxValue).clamp(0.0, 1.0);
          final g = (pixel.g / maxValue).clamp(0.0, 1.0);
          final b = (pixel.b / maxValue).clamp(0.0, 1.0);
          data[index++] = _quantize(r, params).toSigned(8);
          data[index++] = _quantize(g, params).toSigned(8);
          data[index++] = _quantize(b, params).toSigned(8);
        }
      }
      return data.buffer;
    }

    final params = _interpreter.getInputTensor(0).params;
    final data = Uint8List(_inputWidth * _inputHeight * 3);
    var index = 0;
    final maxValue = image.maxChannelValue;
    for (var y = 0; y < _inputHeight; y++) {
      for (var x = 0; x < _inputWidth; x++) {
        final pixel = image.getPixel(x, y);
        final r = (pixel.r / maxValue).clamp(0.0, 1.0);
        final g = (pixel.g / maxValue).clamp(0.0, 1.0);
        final b = (pixel.b / maxValue).clamp(0.0, 1.0);
        data[index++] = _quantize(r, params).clamp(0, 255);
        data[index++] = _quantize(g, params).clamp(0, 255);
        data[index++] = _quantize(b, params).clamp(0, 255);
      }
    }
    return data.buffer;
  }

  int _quantize(double value, QuantizationParams params) {
    if (params.scale == 0) {
      return (value * 255).round();
    }
    return (value / params.scale + params.zeroPoint).round();
  }

  _OutputBundle _allocateOutputBuffers() {
    final outputs = <int, ByteBuffer>{};
    final tensors = _interpreter.getOutputTensors();
    final meta = <_TensorMeta>[];
    for (var i = 0; i < tensors.length; i++) {
      final tensor = tensors[i];
      final bytes = Uint8List(tensor.data.length);
      outputs[i] = bytes.buffer;
      meta.add(
        _TensorMeta(
          tensor: tensor,
          bytes: bytes,
          shape: tensor.shape,
          type: tensor.type,
        ),
      );
    }
    return _OutputBundle(outputs, meta);
  }

  void _logDebugOnce(_OutputBundle outputs) {
    if (_didLogDebug) return;
    _didLogDebug = true;
    try {
      final inputTensor = _interpreter.getInputTensor(0);
      debugPrint(
        'MangroveDetector input shape=${inputTensor.shape} '
        'type=${inputTensor.type} '
        'quant=${inputTensor.params.scale},${inputTensor.params.zeroPoint}',
      );
      for (var i = 0; i < outputs.meta.length; i++) {
        final meta = outputs.meta[i];
        debugPrint(
          'MangroveDetector output[$i] shape=${meta.shape} '
          'type=${meta.type} '
          'quant=${meta.tensor.params.scale},${meta.tensor.params.zeroPoint}',
        );
        final sampleCount = math.min(6, _numElements(meta.shape));
        if (sampleCount <= 0) continue;
        final samples = <double>[];
        for (var j = 0; j < sampleCount; j++) {
          samples.add(_readValue(meta, j));
        }
        debugPrint('MangroveDetector output[$i] sample=$samples');
      }
    } catch (e) {
      debugPrint('MangroveDetector debug log failed: $e');
    }
  }


  _DetectionPrediction? _extractBestPrediction(_OutputBundle outputs) {
    final meta = outputs.meta.firstWhere(
      (tensor) =>
          tensor.shape.length == 3 &&
          tensor.shape[0] == 1 &&
          tensor.shape[1] >= 5,
      orElse: () => _TensorMeta(
        tensor: outputs.meta.first.tensor,
        bytes: Uint8List(0),
        shape: const [],
        type: outputs.meta.first.type,
      ),
    );
    if (meta.shape.isEmpty) return null;

    final channels = meta.shape[1];
    final numBoxes = meta.shape[2];
    if (channels < 5 || numBoxes <= 0) return null;

    var classStart = 4;
    var classCount = channels - classStart;
    var hasObjectness = false;
    if (classCount == _classOrder.length + 1) {
      hasObjectness = true;
      classStart = 5;
      classCount = channels - classStart;
    }
    if (classCount <= 0) return null;

    var bestScore = 0.0;
    var bestClass = -1;
    TreeBounds? bestBounds;

    for (var i = 0; i < numBoxes; i++) {
      final cx = _readChannelValue(meta, 0, i, numBoxes);
      final cy = _readChannelValue(meta, 1, i, numBoxes);
      final w = _readChannelValue(meta, 2, i, numBoxes);
      final h = _readChannelValue(meta, 3, i, numBoxes);

      final objectness = hasObjectness
          ? _normalizeScore(_readChannelValue(meta, 4, i, numBoxes))
          : 1.0;
      var bestClassScore = 0.0;
      var bestClassIndex = 0;
      for (var c = 0; c < classCount; c++) {
        final raw = _readChannelValue(meta, classStart + c, i, numBoxes);
        final score = _normalizeScore(raw) * objectness;
        if (score > bestClassScore) {
          bestClassScore = score;
          bestClassIndex = c;
        }
      }

      if (bestClassScore > bestScore) {
        bestScore = bestClassScore;
        bestClass = bestClassIndex;
        bestBounds = _boxFromCenter(
          cx: cx,
          cy: cy,
          w: w,
          h: h,
        );
      }
    }

    if (bestBounds == null) return null;
    return _DetectionPrediction(
      classIndex: bestClass,
      confidence: bestScore.clamp(0.0, 1.0),
      bounds: bestBounds,
    );
  }

  int _numElements(List<int> shape) {
    if (shape.isEmpty) return 0;
    return shape.fold(1, (value, element) => value * element);
  }

  double _readValue(_TensorMeta meta, int index) {
    final bytes = meta.bytes;
    if (bytes.isEmpty) return 0.0;
    final params = meta.tensor.params;
    if (meta.type == TensorType.float32) {
      final data = ByteData.sublistView(bytes);
      return data.getFloat32(index * 4, Endian.little);
    }
    if (meta.type == TensorType.int8) {
      final raw = bytes[index].toSigned(8);
      final scale = params.scale == 0 ? 1.0 : params.scale;
      return (raw - params.zeroPoint) * scale;
    }
    final raw = bytes[index];
    final scale = params.scale == 0 ? 1.0 : params.scale;
    return (raw - params.zeroPoint) * scale;
  }

  double _normalizeScore(double value) {
    if (value.isNaN) return 0.0;
    if (value < 0.0 || value > 1.0) {
      final sigmoid = 1.0 / (1.0 + math.exp(-value));
      return sigmoid.clamp(0.0, 1.0);
    }
    return value.clamp(0.0, 1.0);
  }

  double _readChannelValue(
    _TensorMeta meta,
    int channel,
    int index,
    int stride,
  ) {
    final offset = channel * stride + index;
    return _readValue(meta, offset);
  }

  TreeBounds _boxFromCenter({
    required double cx,
    required double cy,
    required double w,
    required double h,
  }) {
    var centerX = cx;
    var centerY = cy;
    var width = w;
    var height = h;

    if (centerX > 1.5 || centerY > 1.5 || width > 1.5 || height > 1.5) {
      centerX = centerX / _inputWidth;
      centerY = centerY / _inputHeight;
      width = width / _inputWidth;
      height = height / _inputHeight;
    }

    // Make the bounding box slightly wider (left to right).
    final left = (centerX - width / 1.7).clamp(0.0, 1.0);
    final right = (centerX + width / 1.7).clamp(0.0, 1.0);
    // Make the bounding box higher (taller) by extending the top boundary further up.
    final top = (centerY - height / 1.4).clamp(0.0, 1.0);
    final bottom = (centerY + height / 2.0).clamp(0.0, 1.0);

    return TreeBounds(
      left: math.min(left, right),
      top: math.min(top, bottom),
      right: math.max(left, right),
      bottom: math.max(top, bottom),
    );
  }
}

class _TensorMeta {
  final Tensor tensor;
  final Uint8List bytes;
  final List<int> shape;
  final TensorType type;

  _TensorMeta({
    required this.tensor,
    required this.bytes,
    required this.shape,
    required this.type,
  });
}

class _OutputBundle {
  final Map<int, ByteBuffer> buffers;
  final List<_TensorMeta> meta;

  _OutputBundle(this.buffers, this.meta);
}

class _DetectionPrediction {
  final int classIndex;
  final TreeBounds bounds;
  final double confidence;

  _DetectionPrediction({
    required this.classIndex,
    required this.bounds,
    required this.confidence,
  });
}
