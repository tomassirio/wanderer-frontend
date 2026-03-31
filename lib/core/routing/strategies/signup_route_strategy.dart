import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';

/// Handles `/signup` → AuthScreen (signup / registration mode).
class SignupRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) => uri.path == '/signup';

  @override
  PageRoute build(Uri uri, RouteSettings settings) {
    return PageTransitions.fade(
      const AuthScreen(startInSignup: true),
    );
  }
}
