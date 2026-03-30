import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/privacy_policy_screen.dart';

/// Handles `/privacy-policy` → PrivacyPolicyScreen.
class PrivacyPolicyRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) => uri.path == '/privacy-policy';

  @override
  PageRoute build(Uri uri, RouteSettings settings) {
    return PageTransitions.fade(
      const PrivacyPolicyScreen(),
    );
  }
}
