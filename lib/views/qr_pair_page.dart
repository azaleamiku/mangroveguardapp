import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const Color caribbeanGreen = Color(0xFF00DF81);
const Color antiFlashWhite = Color(0xFFF1F7F6);
const Color darkGreen = Color(0xFF032221);
const Color richBlack = Color(0xFF021B1A);
const Color bangladeshGreen = Color(0xFF03624C);

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
    final savedUrl = prefs.getString('paired_server_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      setState(() {
        _pairedServerUrl = savedUrl;
        _isPaired = true;
      });
    }
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
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawValue = barcode.rawValue!.trim();
    if (rawValue.isEmpty) return;

    final uri = Uri.tryParse(rawValue);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      _showErrorNotification('Invalid QR code. Expected a server URL.');
      return;
    }

    await _stopScanner(silent: true);

    final success = await _attemptPairing(uri.toString());
    if (!mounted) return;

    if (success) {
      setState(() {
        _pairedServerUrl = uri.toString();
        _isPaired = true;
        _isScanning = false;
        _errorMessage = null;
      });
      widget.onPaired?.call();
    } else {
      setState(() {
        _errorMessage = 'Connection failed. Server unreachable.';
        _isScanning = false;
      });
    }
  }

  Future<bool> _attemptPairing(String baseUrl) async {
    final normalizedUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final endpoints = [
      Uri.parse('$normalizedUrl/api/pair/verify'),
      Uri.parse('$normalizedUrl/api/pair/qr'),
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .get(endpoint)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          await _savePairing(normalizedUrl);
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

    try {
      await http
          .get(Uri.parse('$normalizedUrl/api/scans'))
          .timeout(const Duration(seconds: 5));
      await _savePairing(normalizedUrl);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _savePairing(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('paired_server_url', baseUrl);
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
    await prefs.remove('paired_server_url');
    setState(() {
      _pairedServerUrl = null;
      _isPaired = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: richBlack,
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
                          color: antiFlashWhite.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isPaired && _pairedServerUrl != null
                  ? _buildPairedView()
                  : _isScanning
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
                color: bangladeshGreen.withValues(alpha: 0.18),
                border: Border.all(
                  color: caribbeanGreen.withValues(alpha: 0.55),
                  width: 1.8,
                ),
              ),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 42,
                color: caribbeanGreen.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _pairedServerUrl == null && !_isPaired
                  ? 'No Server Connected'
                  : 'Scan QR to Pair',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: antiFlashWhite,
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
                color: antiFlashWhite.withValues(alpha: 0.68),
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
      return const Center(child: CircularProgressIndicator(color: caribbeanGreen));
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
              border: Border.all(color: caribbeanGreen.withValues(alpha: 0.35), width: 2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                'Align QR code within frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: antiFlashWhite.withValues(alpha: 0.8),
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

  Widget _buildPairedView() {
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
                color: caribbeanGreen.withValues(alpha: 0.18),
                border: Border.all(
                  color: caribbeanGreen.withValues(alpha: 0.8),
                  width: 1.8,
                ),
              ),
              child: const Icon(
                Icons.cloud_done_rounded,
                size: 42,
                color: caribbeanGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Device Paired',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: antiFlashWhite,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: darkGreen.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: caribbeanGreen.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.dns_rounded, size: 16, color: caribbeanGreen),
                  const SizedBox(width: 8),
                  Text(
                    _pairedServerUrl ?? '',
                    style: TextStyle(
                      color: antiFlashWhite.withValues(alpha: 0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                ? [bangladeshGreen.withValues(alpha: 0.85), darkGreen.withValues(alpha: 0.95)]
                : [const Color(0xFF14B8A6), const Color(0xFF0F766E)],
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isPaired
                ? caribbeanGreen.withValues(alpha: 0.55)
                : caribbeanGreen.withValues(alpha: 0.85),
            width: isPaired ? 1.4 : 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: caribbeanGreen.withValues(alpha: isPaired ? 0.18 : 0.28),
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
                    color: antiFlashWhite,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isPaired
                        ? 'Unpair Device'
                        : isScanning
                            ? 'Cancel'
                            : 'Scan QR',
                    style: const TextStyle(
                      color: antiFlashWhite,
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
                        valueColor: AlwaysStoppedAnimation<Color>(antiFlashWhite),
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
