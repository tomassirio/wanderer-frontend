import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/user_deep_link_screen.dart';

/// Handles `/user/:username` → UserDeepLinkScreen which resolves
/// the username and then navigates to ProfileScreen.
class UserRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) =>
      uri.pathSegments.length == 2 && uri.pathSegments[0] == 'user';

  @override
  PageRoute build(Uri uri, RouteSettings settings) {
    final username = uri.pathSegments[1];
    return PageTransitions.fade(
      UserDeepLinkScreen(username: username),
    );
  }
}
