import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/plan_route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/reset_password_route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/login_route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/privacy_policy_route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/signup_route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/sso_callback_route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/terms_and_conditions_route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/trip_route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/user_route_strategy.dart';
import 'package:wanderer_frontend/core/routing/strategies/verify_email_route_strategy.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';

/// Central router that delegates to [RouteStrategy] instances.
///
/// Iterates through registered strategies in order; the first match wins.
/// Falls back to [InitialScreen] (home) when no strategy matches.
class AppRouter {
  /// Ordered list of strategies. Add new deep-link strategies here.
  final List<RouteStrategy> _strategies = [
    SsoCallbackRouteStrategy(),
    LoginRouteStrategy(),
    SignupRouteStrategy(),
    VerifyEmailRouteStrategy(),
    ResetPasswordRouteStrategy(),
    PrivacyPolicyRouteStrategy(),
    TermsAndConditionsRouteStrategy(),
    TripRouteStrategy(),
    PlanRouteStrategy(),
    UserRouteStrategy(),
  ];

  /// Called by [MaterialApp.onGenerateRoute].
  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');

    for (final strategy in _strategies) {
      if (strategy.matches(uri)) {
        return strategy.build(uri, settings);
      }
    }

    // Default fallback → home
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => const InitialScreen(),
    );
  }
}
