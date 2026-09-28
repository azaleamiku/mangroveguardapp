import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mangroveguardapp/theme/colors.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import '../constants/app_constants.dart';



class QrPairPage extends StatefulWidget {
  final VoidCallback? onPaired;

  const QrPairPage({super.key, this.onPaired});

  @override
  State<QrPairPage> createState() => _QrPairPageState();
}

class _QrPairPageState extends State<QrPairPage> {
  MobileScannerController? _scannerController;
  bool _isScanning = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _pairedServerUrl;
  bool _isPaired = false;
  bool _isProcessingQr = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkExistingPairing();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPairing() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(AppConstants.pairedServerUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setState(() {
        _pairedServerUrl = savedUrl;
        _isPaired = true;
      });
    }
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

  Future<void> _startScanner() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      await controller.start();

      setState(() {
        _scannerController = controller;
        _isScanning = true;
        _isLoading = false;
      });

      controller.barcodes.listen(_onBarcodeDetected).onError((error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Scanner error: $error';
            _isScanning = false;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start camera: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isPaired || _isProcessingQr) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!.trim();
    if (rawValue.isEmpty) return;

    final uri = Uri.tryParse(rawValue);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      _showErrorNotification('Invalid QR code. Expected a server URL.');
      return;
    }

    _isProcessingQr = true;
    try {
      final baseUrl = uri.origin.replaceAll(RegExp(r'/+$'), '');
      final token = uri.queryParameters['token'];
      final success = await _attemptPairing(baseUrl, token);
      if (!mounted) return;

      if (success) {
        setState(() {
          _pairedServerUrl = baseUrl;
          _isPaired = true;
          _errorMessage = null;
        });
        widget.onPaired?.call();
      } else {
        setState(() {
          _errorMessage = 'Connection failed. Server unreachable.';
        });
      }
    } finally {
      _isProcessingQr = false;
    }
  }

  Future<bool> _attemptPairing(String baseUrl, String? token) async {
    final endpoints = [
      Uri.parse('$baseUrl/${AppConstants.apiScans}'),
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
              final deviceId = prefs.getString(AppConstants.deviceIdKey) ?? 'device-${DateTime.now().millisecondsSinceEpoch}';
              if (!prefs.containsKey(AppConstants.deviceIdKey)) {
                await prefs.setString(AppConstants.deviceIdKey, deviceId);
              }

              final deviceName = await _getDeviceName();

              final confirmResponse = await http
                  .post(
                     Uri.parse('$baseUrl/${AppConstants.apiPairConfirm}'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'token': token,
                      'deviceId': deviceId,
                      'deviceName': deviceName,
                    }),
                  )
                  .timeout(const Duration(seconds: 5));
              if (confirmResponse.statusCode >= 400) {
                String errorMessage = 'Pair confirm rejected: ${confirmResponse.statusCode}';
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
                } on FormatException catch (_) {}
                on ArgumentError catch (_) {}
                debugPrint(errorMessage);
                return false;
              }
            } catch (e) {
              debugPrint('Pair confirm failed: $e');
              return false;
            }
          }

          await _savePairing(baseUrl);
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

  Future<void> _savePairing(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.pairedServerUrlKey, baseUrl);
  }

  Future<void> _stopScanner({bool silent = false}) async {
    final controller = _scannerController;
    if (controller != null) {
      try {
        controller.stop();
        controller.dispose();
      } catch (_) {}
    }
    _scannerController = null;
    if (!silent && mounted) {
      setState(() => _isScanning = false);
    }
  }

  void _showErrorNotification(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _errorMessage = null);
      }
    });
  }

  void _toggleScanner() async {
    if (_isPaired) {
      await _clearPairing();
      return;
    }

    if (_isScanning) {
      await _stopScanner();
    } else {
      await _startScanner();
    }
  }

  Future<void> _clearPairing() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(AppConstants.pairedServerUrlKey);
    final deviceId = prefs.getString(AppConstants.deviceIdKey);
    final sessionId = prefs.getString(AppConstants.sessionIdKey);

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
      } on SocketException catch (_) {}
      on TimeoutException catch (_) {}
      on HttpException catch (_) {}
    }

    if (sessionId != null && sessionId.isNotEmpty) {
      unawaited(MonitoringSyncService.endSession(sessionId));
    }

    await prefs.remove(AppConstants.pairedServerUrlKey);
    setState(() {
      _pairedServerUrl = null;
      _isPaired = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.richBlack,
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.55)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppColors.antiFlashWhite.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isScanning
                  ? _buildScannerView()
                  : _buildIdleView(),
            ),
            _buildToggleButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bangladeshGreen.withValues(alpha: 0.18),
                border: Border.all(
                  color: AppColors.caribbeanGreen.withValues(alpha: 0.55),
                  width: 1.8,
                ),
              ),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 42,
                color: AppColors.caribbeanGreen.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _pairedServerUrl == null && !_isPaired
                  ? 'No Server Connected'
                  : 'Scan QR to Pair',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.antiFlashWhite,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Scan a MangroveGuard server QR code to connect your device and sync scans from anywhere.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.antiFlashWhite.withValues(alpha: 0.68),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    final controller = _scannerController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.caribbeanGreen));
    }

    return Stack(
      children: [
        Positioned.fill(child: MobileScanner(
          controller: controller,
          onDetect: _onBarcodeDetected,
        )),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.caribbeanGreen.withValues(alpha: 0.35), width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                'Align QR code within frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.antiFlashWhite.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton() {
    final isScanning = _isScanning;
    final isPaired = _isPaired;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPaired
                ? [AppColors.bangladeshGreen.withValues(alpha: 0.85), AppColors.darkGreen.withValues(alpha: 0.95)]
                : [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isPaired
                ? AppColors.caribbeanGreen.withValues(alpha: 0.55)
                : AppColors.caribbeanGreen.withValues(alpha: 0.85),
            width: isPaired ? 1.4 : 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.caribbeanGreen.withValues(alpha: isPaired ? 0.18 : 0.28),
              blurRadius: 16,
              spreadRadius: 0.4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _isLoading ? null : _toggleScanner,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Icon(
                    isPaired
                        ? Icons.link_off_rounded
                        : isScanning
                            ? Icons.close_rounded
                            : Icons.qr_code_scanner_rounded,
                    size: 20,
                    color: AppColors.antiFlashWhite,
                  ),
                  const SizedBox(width: 10),
                   Text(
                     isPaired
                         ? 'Unpair'
                         : isScanning
                             ? 'Cancel'
                             : 'Scan QR',
                    style: const TextStyle(
                      color: AppColors.antiFlashWhite,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.antiFlashWhite),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
