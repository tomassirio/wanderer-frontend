import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';

/// Type of notification to display
enum NotificationType {
  success,
  error,
  info,
  warning,
}

/// Configuration for notification types
class _NotificationConfig {
  final Color backgroundColor;
  final IconData icon;

  const _NotificationConfig({
    required this.backgroundColor,
    required this.icon,
  });

  static const Map<NotificationType, _NotificationConfig> configs = {
    NotificationType.success: _NotificationConfig(
      backgroundColor: Color(0xFFFF8C42), // Orange tone for success
      icon: Icons.check_circle,
    ),
    NotificationType.error: _NotificationConfig(
      backgroundColor: Color(0xFFE85D3A), // Darker orange/red for error
      icon: Icons.error,
    ),
    NotificationType.info: _NotificationConfig(
      backgroundColor: Color(0xFFFFB366), // Lighter orange for info
      icon: Icons.info,
    ),
    NotificationType.warning: _NotificationConfig(
      backgroundColor: Color(0xFFFF9F5A), // Medium orange for warning
      icon: Icons.warning,
    ),
  };
}

/// A floating pill-shaped notification that appears at the bottom of the screen
class FloatingNotification {
  /// Shows a floating notification
  static void show(
    BuildContext context,
    String message,
    NotificationType type, {
    Duration duration = const Duration(seconds: 3),
  }) {
    // Web: the canvas "Live notifications" toast stack replaces the pill.
    if (kIsWeb) {
      Toasts.show(ToastData(
        kind: switch (type) {
          NotificationType.success => ToastKind.success,
          NotificationType.error => ToastKind.error,
          NotificationType.info => ToastKind.info,
          NotificationType.warning => ToastKind.error,
        },
        title: message,
      ));
      return;
    }
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _FloatingNotificationOverlay(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }
}

/// Overlay wrapper for the floating notification
class _FloatingNotificationOverlay extends StatefulWidget {
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _FloatingNotificationOverlay({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_FloatingNotificationOverlay> createState() =>
      _FloatingNotificationOverlayState();
}

class _FloatingNotificationOverlayState
    extends State<_FloatingNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    // Auto-dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _NotificationConfig.configs[widget.type]!;

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: config.backgroundColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      config.icon,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
