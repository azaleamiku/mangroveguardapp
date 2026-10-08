import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

import '../services/mangrove_detector.dart';

const String liveIsolateReady = 'ready';
const String liveIsolateProcess = 'process';
const String liveIsolateResult = 'result';
const String liveIsolateError = 'error';
const String liveIsolateStop = 'stop';

int _clampByte(num value) {
  if (value < 0) return 0;
  if (value > 255) return 255;
  return value.round();
}

img.Image convertYuv420ToRgb({
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

Rect? cropRectFromNormalized({
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

void liveAssessmentIsolate(Map<String, Object?> config) async {
  final sendPort = config['sendPort'] as SendPort;
  final modelData = config['modelData'] as TransferableTypedData;
  final modelBytes = modelData.materialize().asUint8List();

  MangroveDetector detector;
  try {
    detector = await MangroveDetector.createFromBuffer(modelBytes);
  } catch (e) {
    sendPort.send({'type': liveIsolateError, 'error': e.toString()});
    return;
  }

  final receivePort = ReceivePort();
  sendPort.send({'type': liveIsolateReady, 'sendPort': receivePort.sendPort});

  await for (final message in receivePort) {
    if (message is! Map<String, Object?>) continue;
    final type = message['type'];
    if (type == liveIsolateStop) {
      break;
    }
    if (type != liveIsolateProcess) continue;

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

      var rgb = convertYuv420ToRgb(
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
        final rect = cropRectFromNormalized(
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
        'type': liveIsolateResult,
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
        'type': liveIsolateError,
        'requestId': requestId,
        'error': e.toString(),
      });
    }
  }

  detector.dispose();
  receivePort.close();
}

sealed class LiveIsolateEvent {
  const LiveIsolateEvent();
}

class LiveIsolateReadyEvent extends LiveIsolateEvent {
  final SendPort sendPort;

  const LiveIsolateReadyEvent(this.sendPort);
}

class LiveIsolateResultEvent extends LiveIsolateEvent {
  final int requestId;
  final String? assessmentName;
  final double? confidence;
  final Rect? boundingBox;

  const LiveIsolateResultEvent({
    required this.requestId,
    this.assessmentName,
    this.confidence,
    this.boundingBox,
  });
}

class LiveIsolateErrorEvent extends LiveIsolateEvent {
  final int? requestId;
  final String error;

  const LiveIsolateErrorEvent({required this.error, this.requestId});
}

class LiveIsolateMessageHandler {
  SendPort? sendPort;
  bool isReady = false;
  int pendingRequestId = 0;

  LiveIsolateEvent? handle(dynamic message) {
    if (message is! Map) return null;
    final type = message['type'];
    if (type == liveIsolateReady) {
      sendPort = message['sendPort'] as SendPort?;
      isReady = sendPort != null;
      final port = sendPort;
      return port == null ? null : LiveIsolateReadyEvent(port);
    }
    if (type == liveIsolateResult) {
      final requestId = message['requestId'] as int?;
      if (requestId == null || requestId != pendingRequestId) {
        return null;
      }
      return LiveIsolateResultEvent(
        requestId: requestId,
        assessmentName: message['assessment'] as String?,
        confidence: message['confidence'] as double?,
        boundingBox: _parseBoundingBox(message['boundingBox']),
      );
    }
    if (type == liveIsolateError) {
      return LiveIsolateErrorEvent(
        requestId: message['requestId'] as int?,
        error: message['error'] as String? ?? 'Unknown live assessment error',
      );
    }
    return null;
  }

  static Rect? _parseBoundingBox(Map<Object?, Object?>? bboxMap) {
    if (bboxMap == null) return null;
    return Rect.fromLTRB(
      (bboxMap['left'] as num).toDouble(),
      (bboxMap['top'] as num).toDouble(),
      (bboxMap['right'] as num).toDouble(),
      (bboxMap['bottom'] as num).toDouble(),
    );
  }
}
