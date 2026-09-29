import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/sso_callback_screen.dart';

/// Handles `/auth/sso-callback` → SsoCallbackScreen.
class SsoCallbackRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) => uri.path == ApiEndpoints.ssoWebCallbackPath;

  @override
  PageRoute build(Uri uri, RouteSettings settings) {
    return PageTransitions.fade(
      SsoCallbackScreen(
        code: uri.queryParameters['code'],
        error: uri.queryParameters['error'],
      ),
    );
  }
}
