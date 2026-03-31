import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';

/// Handles `/login` and `/auth` → AuthScreen (login mode).
///
/// Supports `?username=` query parameter to pre-fill the username field.
/// This is used after email verification or password reset success.
class LoginRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) => uri.path == '/login' || uri.path == '/auth';

  @override
  PageRoute build(Uri uri, RouteSettings settings) {
    final username = uri.queryParameters['username'];
    return PageTransitions.fade(
      AuthScreen(initialUsername: username),
    );
  }
}
