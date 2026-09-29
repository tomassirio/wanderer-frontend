import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_auth_widgets.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_explore_tab.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

/// Android logged-out entry (canvas: "Welcome (logged out)").
class AndroidWelcomeScreen extends ConsumerStatefulWidget {
  const AndroidWelcomeScreen({super.key});

  @override
  ConsumerState<AndroidWelcomeScreen> createState() =>
      _AndroidWelcomeScreenState();
}

class _AndroidWelcomeScreenState extends ConsumerState<AndroidWelcomeScreen> {
  List<Trip> _featured = const [];

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  // Same source as the web landing page: public trips, promoted first.
  Future<void> _loadFeatured() async {
    try {
      final page =
          await ref.read(tripServiceProvider).getPublicTrips(page: 0, size: 6);
      final trips = [...page.content]
        ..sort((a, b) => (b.isPromoted ? 1 : 0) - (a.isPromoted ? 1 : 0));
      if (mounted) setState(() => _featured = trips.take(3).toList());
    } catch (_) {
      // Section just stays hidden.
    }
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(PageTransitions.fade(screen));

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(children: [
                const WandererLogo(size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Wanderer',
                      style: WandererTheme.display(20, color: c.text)),
                ),
                const AndroidAuthHeaderActions(),
              ]),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Pill(l10n.landingFreeBadge, tone: PillTone.promoted),
                      const SizedBox(height: 14),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: l10n.landingHeroBefore),
                          TextSpan(
                              text: l10n.landingHeroAccent,
                              style:
                                  const TextStyle(color: WandererTheme.trail)),
                          TextSpan(text: l10n.landingHeroAfter),
                        ]),
                        style: WandererTheme.display(36, color: c.text)
                            .copyWith(height: 1.05, letterSpacing: -0.7),
                      ),
                      const SizedBox(height: 14),
                      Text(l10n.welcomeHeroSubShort,
                          style: TextStyle(
                              fontSize: 16, height: 1.55, color: c.textMuted)),
                    ],
                  ),
                ),
                if (_featured.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(children: [
                      Expanded(
                        child: Text(l10n.welcomeFeaturedTrips,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: c.text)),
                      ),
                      TextButton(
                        onPressed: () => _push(const AndroidExploreTab()),
                        child: Text(l10n.seeAll,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.accentText)),
                      ),
                    ]),
                  ),
                  for (final trip in _featured) ...[
                    const SizedBox(height: 12),
                    _FeaturedCard(
                        trip: trip,
                        onTap: () => _push(TripDetailScreen(trip: trip))),
                  ],
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: c.ground,
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                androidPrimaryButton(l10n.welcomeCreateFreeAccount,
                    onPressed: () =>
                        _push(const AuthScreen(startInSignup: true))),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => _push(const AuthScreen()),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: c.surface,
                      foregroundColor: c.text,
                      side: BorderSide(color: c.line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: Text(l10n.welcomeHaveAccount),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  const _FeaturedCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final km = trip.accruedDistanceKm;
    final meta = [
      '@${trip.username}',
      if (km != null && km > 0) l10n.kmValue(km.toStringAsFixed(1)),
      l10n.publicVisibility,
    ].join(' · ');
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 170,
              child: Stack(fit: StackFit.expand, children: [
                CachedTripThumbnail(
                  thumbnailUrl: trip.thumbnailUrl,
                  placeholder: Container(color: c.mapGround),
                  errorWidget: Container(color: c.mapGround),
                ),
                Positioned(
                    top: 12,
                    left: 12,
                    child: Pill.status(context, trip.status, onImage: true)),
                if (trip.isPromoted)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Pill(l10n.promoted,
                        tone: PillTone.onImage,
                        foregroundTone: PillTone.promoted),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WandererTheme.display(19, color: c.text)),
                  const SizedBox(height: 3),
                  Text(meta, style: TextStyle(fontSize: 13, color: c.caption)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
