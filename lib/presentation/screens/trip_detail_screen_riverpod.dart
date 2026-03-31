import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/state/trip_detail/trip_detail_notifier.dart';

/// Consumer wrapper for TripDetailScreen that provides Riverpod state
/// This allows gradual migration from setState to Riverpod without breaking existing code
class TripDetailScreenWrapper extends ConsumerWidget {
  final Trip trip;

  const TripDetailScreenWrapper({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the provider for this trip
    final state = ref.watch(tripDetailProvider(trip));

    // For now, pass the provider to the existing screen
    // Later, we can migrate sections of the screen to use the provider directly
    return _TripDetailScreenInternal(
      trip: trip,
      tripDetailState: state,
      tripDetailNotifier: ref.read(tripDetailProvider(trip).notifier),
    );
  }
}

/// Internal trip detail screen that can access both old setState and new Riverpod
/// This is temporary during migration
class _TripDetailScreenInternal extends StatefulWidget {
  final Trip trip;
  final TripDetailScreenState tripDetailState;
  final TripDetailNotifier tripDetailNotifier;

  const _TripDetailScreenInternal({
    required this.trip,
    required this.tripDetailState,
    required this.tripDetailNotifier,
  });

  @override
  State<_TripDetailScreenInternal> createState() =>
      _TripDetailScreenInternalState();
}

class _TripDetailScreenInternalState extends State<_TripDetailScreenInternal> {
  // TODO: Gradually migrate state variables to use widget.tripDetailState instead
  // For now, keep existing implementation but can start using Riverpod state

  @override
  Widget build(BuildContext context) {
    // Can access both:
    // - Old: this.setState(...)
    // - New: widget.tripDetailNotifier.updateTrip(...)

    return Scaffold(
      // TODO: Copy existing build implementation here
      body: Center(
        child: Text('Migrating to Riverpod...'),
      ),
    );
  }
}
