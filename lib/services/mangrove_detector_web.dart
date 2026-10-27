import 'dart:typed_data';

import '../models/mangrove_tree.dart';
import '../models/result.dart';

class MangroveDetectionResult {
  final MangroveTree tree;
  final double? predictionConfidence;
  final dynamic predictedAssessment;
  final dynamic boundingBox;

  const MangroveDetectionResult({
    required this.tree,
    this.predictionConfidence,
    this.predictedAssessment,
    this.boundingBox,
  });
}

class MangroveDetector {
  static const String modelAssetPath = 'assets/models/mangroveModel.tflite';

  static Future<MangroveDetector> create() async {
    throw UnsupportedError('Mangrove detection is not supported on web.');
  }

  static Future<MangroveDetector> createFromBuffer(Uint8List modelBytes) async {
    throw UnsupportedError('Mangrove detection is not supported on web.');
  }

  static Future<Uint8List> loadModelBytes() async {
    throw UnsupportedError('Mangrove detection is not supported on web.');
  }

  void dispose() {}

  Future<Result<MangroveDetectionResult, DetectionError>> detect(String imagePath) async {
    throw UnsupportedError('Mangrove detection is not supported on web.');
  }

  Future<Result<MangroveDetectionResult, DetectionError>> detectFromImage(dynamic image) async {
    throw UnsupportedError('Mangrove detection is not supported on web.');
  }
}
