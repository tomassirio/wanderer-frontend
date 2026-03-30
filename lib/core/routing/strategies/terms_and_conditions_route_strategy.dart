import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/terms_and_conditions_screen.dart';

/// Handles `/terms-and-conditions` → TermsAndConditionsScreen.
class TermsAndConditionsRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) => uri.path == '/terms-and-conditions';

  @override
  PageRoute build(Uri uri, RouteSettings settings) {
    return PageTransitions.fade(
      const TermsAndConditionsScreen(),
    );
  }
}
