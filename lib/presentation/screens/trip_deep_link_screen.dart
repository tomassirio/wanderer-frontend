import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/errors/app_exception.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/mobile_web/mobile_web_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';

/// Wrapper screen that resolves a trip ID from a deep link URL
/// and navigates to the full TripDetailScreen once loaded.
class TripDeepLinkScreen extends ConsumerStatefulWidget {
  final String tripId;

  /// Open centred on the latest update (check-in notifications).
  final bool focusLatestUpdate;

  const TripDeepLinkScreen(
      {super.key, required this.tripId, this.focusLatestUpdate = false});

  @override
  ConsumerState<TripDeepLinkScreen> createState() => _TripDeepLinkScreenState();
}

class _TripDeepLinkScreenState extends ConsumerState<TripDeepLinkScreen> {
  late final TripService _tripService;
  bool _isLoading = true;
  String? _error;
  int? _statusCode;

  @override
  void initState() {
    super.initState();
    _tripService = ref.read(tripServiceProvider);
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _statusCode = null;
    });
    try {
      final trip = await _tripService.getTripById(widget.tripId);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageTransitions.slideFromRight(TripDetailScreen(
              trip: trip, focusLatestUpdate: widget.focusLatestUpdate)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusCode = e is ApiException
              ? e.statusCode
              : e is AuthenticationRedirectException
                  ? 401
                  : null;
          _error =
              'Could not load trip: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_isLoading && AdaptiveLayout.isMobileWeb(context)) {
      final restricted = _statusCode == 401 || _statusCode == 403;
      final missing = _statusCode == 404;
      return MobileWebMessage(
        icon: restricted
            ? Icons.lock_outline
            : missing
                ? Icons.explore_off_outlined
                : Icons.cloud_off,
        title: restricted
            ? l10n.mobileWebTripRestricted
            : missing
                ? l10n.mobileWebTripUnavailable
                : l10n.errorLoadingTrips,
        message: restricted
            ? l10n.mobileWebTripRestrictedBody
            : missing
                ? l10n.mobileWebTripUnavailableBody
                : l10n.errorLoadingTrips,
        actions: [
          if (restricted)
            FilledButton(
              onPressed: () async {
                final loggedIn = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) =>
                            const AuthScreen(returnToCaller: true)));
                if (loggedIn == true && mounted) _loadTrip();
              },
              child: Text(l10n.logIn),
            ),
          if (!missing)
            OutlinedButton(onPressed: _loadTrip, child: Text(l10n.retry)),
          OutlinedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen())),
              child: Text(l10n.mobileWebExplore)),
          TextButton(
              onPressed: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (_) => false),
              child: Text(l10n.goHome)),
        ],
      );
    }
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
