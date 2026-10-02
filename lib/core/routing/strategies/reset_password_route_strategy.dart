import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/screens/reset_password_screen.dart';

class ResetPasswordRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) => uri.path == '/reset-password';

  @override
  PageRoute build(Uri uri, RouteSettings settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) =>
            ResetPasswordScreen(token: uri.queryParameters['token'] ?? ''),
      );
}
