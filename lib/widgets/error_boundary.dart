import 'package:mangroveguardapp/theme/colors.dart';
import 'package:flutter/material.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, VoidCallback onRetry)? fallback;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback != null
          ? widget.fallback!(_error!, _reset)
          : _DefaultFallback(error: _error!, onRetry: _reset);
    }
    return widget.child;
  }

  void _reset() {
    setState(() => _error = null);
  }
}

class _DefaultFallback extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _DefaultFallback({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'Something went wrong.',
              style: TextStyle(
                color: Colors.grey.shade100,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.caribbeanGreen,
                foregroundColor: AppColors.richBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
