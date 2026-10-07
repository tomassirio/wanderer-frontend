import 'package:flutter/material.dart';
import 'package:wanderer_frontend/presentation/widgets/common/legal_document.dart';
import 'package:wanderer_frontend/presentation/helpers/adaptive_layout.dart';
import 'package:wanderer_frontend/presentation/widgets/landing/landing_hero.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/locale_controller.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/theme_controller.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/screens/home_screen.dart';
import 'package:wanderer_frontend/presentation/screens/initial_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/cached_trip_thumbnail.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

/// Public landing page for logged-out web visitors: headline, two calls to
/// action, a product preview, three feature cards and featured public trips.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final _featuresKey = GlobalKey();
  final _exploreKey = GlobalKey();
  final _aboutKey = GlobalKey();
  List<Trip> _featured = const [];
  bool _featuredFailed = false;

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  Future<void> _loadFeatured() async {
    try {
      final page =
          await ref.read(tripServiceProvider).getPublicTrips(page: 0, size: 6);
      final trips = [...page.content]
        ..sort((a, b) => (b.isPromoted ? 1 : 0) - (a.isPromoted ? 1 : 0));
      if (mounted) {
        setState(() {
          _featured = trips.take(2).toList();
          _featuredFailed = false;
        });
      }
    } catch (e) {
      debugPrint('Featured trips failed: $e');
      if (mounted) setState(() => _featuredFailed = true);
    }
  }

  Future<void> _openAuth({bool startInSignup = false}) async {
    final result = await Navigator.push(
      context,
      PageTransitions.fade(AuthScreen(startInSignup: startInSignup)),
    );
    if (result == true && mounted) {
      Navigator.of(context).pushReplacement(
        PageTransitions.fade(const InitialScreen()),
      );
    }
  }

  void _openExplore() =>
      Navigator.push(context, PageTransitions.fade(const HomeScreen()));

  Future<void> _openPlayStore() async {
    try {
      await launchUrl(Uri.parse(ApiEndpoints.playStoreUrl),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        UiHelpers.showErrorMessage(context, 'Could not open Google Play');
      }
    }
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Scaffold(
      backgroundColor: c.ground,
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final gutter = w >= 1200 ? 120.0 : (w >= 720 ? 40.0 : 16.0);
        final wide = w >= 960;
        final compact = w < AdaptiveLayout.desktopBreakpoint;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, gutter, w - 2 * gutter >= 1100,
                  compact: compact),
              _buildHero(context, gutter, wide, compact: compact),
              _buildFeatures(context, gutter, wide),
              _buildFeatured(context, gutter, wide),
              _buildFooter(context, gutter),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader(BuildContext context, double gutter, bool wide,
      {required bool compact}) {
    if (compact) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
        child: const LandingBrandHeader(),
      );
    }
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final link =
        TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.text);
    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Row(
        children: [
          const WandererLogo(size: 36),
          const SizedBox(width: 10),
          Text('Wanderer', style: WandererTheme.display(22)),
          const Spacer(),
          if (wide) ...[
            TextButton(
                onPressed: _openExplore,
                child: Text(l10n.landingNavExplore, style: link)),
            const SizedBox(width: 12),
            TextButton(
                onPressed: () => _scrollTo(_featuresKey),
                child: Text(l10n.landingNavFeatures, style: link)),
            const SizedBox(width: 12),
            TextButton(
                onPressed: () => _scrollTo(_aboutKey),
                child: Text(l10n.landingNavAbout, style: link)),
            const Spacer(),
          ],
          IconButton(
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? l10n.switchToLightMode
                : l10n.switchToDarkMode,
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: () => ThemeController()
                .setDarkMode(Theme.of(context).brightness != Brightness.dark),
          ),
          const SizedBox(width: 4),
          const _LanguageMenu(),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _openAuth(),
            child: Text(l10n.logIn,
                style: link.copyWith(fontWeight: FontWeight.w700)),
          ),
          if (wide) ...[
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _openAuth(startInSignup: true),
              child: Text(l10n.landingGetStartedFree),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, double gutter, bool wide,
      {required bool compact}) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final headlineSize = wide
        ? 68.0
        : compact
            ? 34.0
            : 40.0;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LandingFreeBadge(),
        const SizedBox(height: 28),
        LandingHeadline(fontSize: headlineSize),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(l10n.landingHeroSub,
              style: TextStyle(
                  fontSize: compact ? 16 : 19,
                  height: 1.6,
                  color: c.textMuted)),
        ),
        const SizedBox(height: 28),
        Wrap(spacing: 12, runSpacing: 12, children: [
          ElevatedButton(
            onPressed: () => _openAuth(startInSignup: !compact),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              textStyle: const TextStyle(
                  fontFamily: WandererTheme.bodyFont,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            child: Text(compact ? l10n.logIn : l10n.landingStartFirstTrip),
          ),
          OutlinedButton(
            onPressed: _openExplore,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              textStyle: const TextStyle(
                  fontFamily: WandererTheme.bodyFont,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
            child: Text(l10n.explorePublicTrips),
          ),
        ]),
        const SizedBox(height: 28),
        Wrap(spacing: 28, runSpacing: 8, children: [
          for (final label in [
            l10n.landingCheckLive,
            l10n.landingCheckComments,
            l10n.landingCheckPrivacy,
          ])
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check, size: 18, color: c.forestFg),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.neutralFg))),
            ]),
        ]),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
          gutter,
          wide
              ? 72
              : compact
                  ? 24
                  : 32,
          gutter,
          compact ? 48 : 96),
      child: wide
          ? Row(children: [
              Expanded(child: copy),
              const SizedBox(width: 56),
              const Expanded(child: LandingProductPreview()),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              copy,
              const SizedBox(height: 48),
              const LandingProductPreview(),
            ]),
    );
  }

  Widget _buildFeatures(BuildContext context, double gutter, bool wide) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final features = [
      (
        Icons.place_outlined,
        c.trailSoftBg,
        c.trailSoftFg,
        l10n.landingFeatureTrackingTitle,
        l10n.landingFeatureTrackingLong
      ),
      (
        Icons.chat_bubble_outline,
        c.forestBg,
        c.forestFg,
        l10n.landingFeatureSocialTitle,
        l10n.landingFeatureSocialLong
      ),
      (
        Icons.emoji_events_outlined,
        c.goldBg,
        c.goldFg,
        l10n.landingFeatureAchievementsTitle,
        l10n.landingFeatureAchievementsLong
      ),
    ];
    final cards = [
      for (final (icon, bg, fg, title, body) in features)
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
            border: Border.all(color: c.lineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        BorderRadius.circular(WandererTheme.radiusCard)),
                child: Icon(icon, color: fg),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Text(body,
                  style:
                      TextStyle(fontSize: 15, height: 1.6, color: c.textMuted)),
            ],
          ),
        ),
    ];

    return Container(
      key: _featuresKey,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.symmetric(horizontal: BorderSide(color: c.line)),
      ),
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
              eyebrow: l10n.landingWhatYouGet,
              title: l10n.landingFeaturesTitle),
          const SizedBox(height: 40),
          _ResponsiveRow(wide: wide, children: cards),
        ],
      ),
    );
  }

  Widget _buildFeatured(BuildContext context, double gutter, bool wide) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final cta = Container(
      constraints: const BoxConstraints(minHeight: 300),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: identical(c, WandererColors.dark) ? c.raised : WandererTheme.ink,
        borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.landingFeaturedCtaTitle,
                style: WandererTheme.display(26, color: Colors.white)
                    .copyWith(height: 1.15)),
            const SizedBox(height: 10),
            Text(l10n.landingFeaturedCtaSub,
                style: const TextStyle(
                    fontSize: 15, height: 1.6, color: Color(0xFFD6D3D1))),
          ]),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _openAuth(startInSignup: true),
            child: Text(l10n.landingGetStartedFree),
          ),
        ],
      ),
    );

    return Padding(
      key: _exploreKey,
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            runSpacing: 12,
            children: [
              _SectionHeading(
                  eyebrow: l10n.landingFromCommunity,
                  title: l10n.featuredTrips),
              TextButton.icon(
                onPressed: _openExplore,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(l10n.landingSeeAllPublic),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_featuredFailed) ...[
            Text(l10n.errorLoadingTrips, style: TextStyle(color: c.textMuted)),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: _loadFeatured, child: Text(l10n.retry))),
            const SizedBox(height: 16),
          ],
          _ResponsiveRow(wide: wide, children: [
            for (final trip in _featured)
              _FeaturedTripCard(
                trip: trip,
                onTap: () => Navigator.push(context,
                    PageTransitions.fade(TripDetailScreen(trip: trip))),
              ),
            cta,
          ]),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, double gutter) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final muted = TextStyle(fontSize: 14, color: c.textMuted);
    return Container(
      key: _aboutKey,
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 32),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 16,
        children: [
          Wrap(spacing: 10, children: [
            Text('Wanderer',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
            Text(l10n.landingFooterTagline, style: muted),
          ]),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: () =>
                    showLegalDocument(context, LegalDocument.privacy),
                child: Text(l10n.privacyPolicy, style: muted),
              ),
              TextButton(
                onPressed: () =>
                    showLegalDocument(context, LegalDocument.terms),
                child: Text(l10n.termsShort, style: muted),
              ),
              TextButton(
                onPressed: () => launchUrl(
                    Uri.parse('https://buymeacoffee.com/tomassirio'),
                    mode: LaunchMode.externalApplication),
                child: Text(l10n.buyMeACoffee, style: muted),
              ),
              Semantics(
                button: true,
                label: l10n.landingInstallCta,
                child: InkWell(
                  onTap: _openPlayStore,
                  child: Image.asset('assets/images/google-play-badge.png',
                      height: 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  const _SectionHeading({required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(eyebrow.toUpperCase(),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: c.accentText)),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            child: Text(title, style: WandererTheme.display(40)),
          ),
        ],
      ),
    );
  }
}

/// Equal-width row on wide screens, stacked column otherwise.
class _ResponsiveRow extends StatelessWidget {
  final bool wide;
  final List<Widget> children;
  const _ResponsiveRow({required this.wide, required this.children});

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 24),
            children[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 24),
            Expanded(child: children[i]),
          ],
          // Keep three columns even with fewer featured trips.
          for (var i = children.length; i < 3; i++) ...[
            const SizedBox(width: 24),
            const Expanded(child: SizedBox()),
          ],
        ],
      ),
    );
  }
}

class _FeaturedTripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  const _FeaturedTripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final km = trip.accruedDistanceKm;
    final meta = [
      '@${trip.username}',
      if (km != null && km > 0) l10n.kmValue(km.toStringAsFixed(1)),
      l10n.commentsCount(trip.commentsCount),
    ].join(' · ');
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
        side: BorderSide(color: c.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 200,
              child: Stack(fit: StackFit.expand, children: [
                CachedTripThumbnail(
                  thumbnailUrl: trip.thumbnailUrl,
                  placeholder: Container(color: c.mapGround),
                  errorWidget: Container(color: c.mapGround),
                ),
                Positioned(
                    top: 14,
                    left: 14,
                    child: Pill.status(context, trip.status, onImage: true)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WandererTheme.display(20)),
                  const SizedBox(height: 6),
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

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu();

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final controller = LocaleController();
    final current = controller.languageCode;
    return PopupMenuButton<String>(
      tooltip: 'Change language',
      onSelected: (code) => controller.setLocale(Locale(code)),
      itemBuilder: (_) => [
        for (final locale in LocaleController.supportedLocales)
          PopupMenuItem(
            value: locale.languageCode,
            child: Text(context.l10n.languageNameFor(locale.languageCode)),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.line),
        ),
        child: Text(LocaleController.localeLabels[current] ?? 'EN',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: c.neutralFg)),
      ),
    );
  }
}
