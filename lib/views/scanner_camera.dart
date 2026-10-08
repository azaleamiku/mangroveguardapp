import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

ImageFormatGroup? resolveCameraFormatGroup({required bool isAndroid}) {
  if (isAndroid) {
    return null;
  }
  return ImageFormatGroup.bgra8888;
}

class CameraLifecycle {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  bool initInFlight = false;
  bool isCheckingPermission = false;

  bool isPermissionDenied = false;
  bool isPermanentlyDenied = false;
  bool isInitializing = true;
  String? cameraError;

  bool get isInitialized =>
      controller != null && controller!.value.isInitialized;

  bool get isStreaming =>
      controller != null &&
      controller!.value.isInitialized &&
      controller!.value.isStreamingImages;

  void resetPermissionState() {
    isPermissionDenied = false;
    isPermanentlyDenied = false;
    isCheckingPermission = false;
  }

  void setInitializing(bool value, [String? error]) {
    isInitializing = value;
    cameraError = error;
  }

  void disposeController() {
    final controller = this.controller;
    if (controller == null) return;
    this.controller = null;
    try {
      controller.dispose();
    } catch (_) {
      debugPrint('Failed to dispose camera controller cleanly');
    }
  }

  Future<void> disposeControllerAsync() async {
    final controller = this.controller;
    if (controller == null) return;
    this.controller = null;
    try {
      await controller.dispose();
    } catch (e) {
      debugPrint('Failed to dispose camera controller cleanly: $e');
    }
  }

  void stopImageStream() {
    final controller = this.controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (controller.value.isStreamingImages) {
        controller.stopImageStream();
      }
    } catch (_) {}
  }

  void startImageStream(void Function(CameraImage) onImage) {
    final controller = this.controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (!controller.value.isStreamingImages) {
        controller.startImageStream(onImage);
      }
    } catch (_) {}
  }

  Future<void> configureForFastCapture(CameraController controller) async {
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

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      resetPermissionState();
      return true;
    }
    if (status.isPermanentlyDenied) {
      isPermissionDenied = true;
      isPermanentlyDenied = true;
      return false;
    }

    final granted = await Permission.camera.request();
    if (granted.isGranted) {
      resetPermissionState();
      return true;
    }
    if (granted.isPermanentlyDenied) {
      isPermissionDenied = true;
      isPermanentlyDenied = true;
      return false;
    }
    isPermissionDenied = true;
    isPermanentlyDenied = false;
    return false;
  }

  Future<void> ensureCameras() async {
    if (cameras.isNotEmpty) return;
    try {
      cameras = await availableCameras();
    } catch (_) {
      cameras = [];
    }
  }

  CameraDescription selectCamera() {
    return cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
  }

  Future<CameraController?> createController() async {
    await ensureCameras();
    if (cameras.isEmpty) return null;

    final selectedCamera = selectCamera();
    final controller = CameraController(
      selectedCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: resolveCameraFormatGroup(isAndroid: Platform.isAndroid),
    );
    return controller;
  }
}
