import 'package:flutter/material.dart';

/// Standardized page route transitions for the Wanderer app
/// Provides consistent, smooth animations across all screen transitions
class PageTransitions {
  // Standardized timing - shorter for snappier feel
  static const Duration _transitionDuration = Duration(milliseconds: 250);
  static const Curve _curve = Curves.easeOutCubic;

  /// Standard fade transition - clean and simple
  static PageRouteBuilder fade(Widget page) {
    return PageRouteBuilder(
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: _curve),
          ),
          child: child,
        );
      },
    );
  }

  /// Slide from right (for forward navigation)
  static PageRouteBuilder slideFromRight(Widget page) {
    return PageRouteBuilder(
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: _curve));

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  /// Slide from left (for backward navigation)
  static PageRouteBuilder slideFromLeft(Widget page) {
    return PageRouteBuilder(
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: _curve));

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  /// Slide from bottom (for modal-style screens)
  static PageRouteBuilder slideFromBottom(Widget page) {
    return PageRouteBuilder(
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: _curve));

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  // Legacy aliases for backwards compatibility
  @Deprecated('Use slideFromRight instead')
  static PageRouteBuilder slideRight(Widget page) => slideFromRight(page);

  @Deprecated('Use slideFromLeft instead')
  static PageRouteBuilder slideLeft(Widget page) => slideFromLeft(page);

  @Deprecated('Use slideFromBottom instead')
  static PageRouteBuilder slideUp(Widget page) => slideFromBottom(page);
}
