import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/verify_email_screen.dart';

/// Handles `/verify-email` → VerifyEmailScreen.
class VerifyEmailRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) => uri.path == '/verify-email';

  @override
  PageRoute build(Uri uri, RouteSettings settings) {
    final token = uri.queryParameters['token'];
    return PageTransitions.fade(
      VerifyEmailScreen(initialToken: token),
    );
  }
}
