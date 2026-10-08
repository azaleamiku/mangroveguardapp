import 'package:flutter/material.dart';

import '../../theme/colors.dart';

class ScannerMenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Animation<double> animation;
  final VoidCallback onTap;

  const ScannerMenuAction({
    super.key,
    required this.icon,
    required this.label,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: animation,
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.darkGreen.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.caribbeanGreen.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.antiFlashWhite,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: label,
                child: GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkGreen.withValues(alpha: 0.92),
                      border: Border.all(
                        color: AppColors.caribbeanGreen.withValues(alpha: 0.55),
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
                    child: Icon(
                      icon,
                      color: AppColors.caribbeanGreen,
                      size: 22,
                    ),
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

class TopNotificationContent extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const TopNotificationContent({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<TopNotificationContent> createState() =>
      _TopNotificationContentState();
}

class _TopNotificationContentState extends State<TopNotificationContent> {
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
            color: AppColors.darkGreen.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.caribbeanGreen.withValues(alpha: 0.35),
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
                color: AppColors.caribbeanGreen,
                size: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                  child: Text(
                    widget.message,
                  style: const TextStyle(
                    color: AppColors.antiFlashWhite,
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