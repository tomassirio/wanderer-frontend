import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/routing/route_strategy.dart';
import 'package:wanderer_frontend/presentation/screens/plan_deep_link_screen.dart';

class PlanRouteStrategy implements RouteStrategy {
  @override
  bool matches(Uri uri) =>
      uri.pathSegments.length == 2 && uri.pathSegments.first == 'plan';

  @override
  PageRoute build(Uri uri, RouteSettings settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => PlanDeepLinkScreen(planId: uri.pathSegments[1]),
      );
}
