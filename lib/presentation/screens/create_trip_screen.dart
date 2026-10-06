import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:wanderer_frontend/presentation/screens/android/ready_trip_screen.dart';
import 'package:wanderer_frontend/presentation/screens/create_trip_plan_screen.dart';

/// "New trip" from any entry point (+ → Trip, Start a trip, badges).
/// Phones and mobile web get the trip screen, ready to start. Desktop web
/// can't track, so it plans instead; the trip is started on the phone.
class CreateTripScreen extends StatelessWidget {
  const CreateTripScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      AdaptiveLayout.usesDesktopLayout(context)
          ? const CreateTripPlanScreen()
          : const ReadyTripScreen();
}
