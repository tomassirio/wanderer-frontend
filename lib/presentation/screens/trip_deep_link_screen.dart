import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';

/// Wrapper screen that resolves a trip ID from a deep link URL
/// and navigates to the full TripDetailScreen once loaded.
class TripDeepLinkScreen extends StatefulWidget {
  final String tripId;

  const TripDeepLinkScreen({super.key, required this.tripId});

  @override
  State<TripDeepLinkScreen> createState() => _TripDeepLinkScreenState();
}

class _TripDeepLinkScreenState extends State<TripDeepLinkScreen> {
  final TripService _tripService = TripService();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      final trip = await _tripService.getTripById(widget.tripId);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageTransitions.slideFromRight(TripDetailScreen(trip: trip)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              'Could not load trip: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingTripDeepLink,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'An unknown error occurred',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (_) => false),
                    child: Text(l10n.goHome),
                  ),
                ],
              ),
      ),
    );
  }
}
