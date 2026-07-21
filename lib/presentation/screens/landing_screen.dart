import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/screens/auth_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

/// Pre-signup marketing landing page shown to logged-out web visitors.
/// Goal: drive Google Play installs. Logged-in and mobile guests are
/// unaffected — see `InitialScreen`.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tomassirio.wanderer.wanderer_frontend';

  Future<void> _openPlayStore(BuildContext context) async {
    final uri = Uri.parse(_playStoreUrl);
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        UiHelpers.showErrorMessage(context, 'Could not open Google Play');
      }
    } catch (e) {
      if (context.mounted) {
        UiHelpers.showErrorMessage(context, 'Error opening Google Play: $e');
      }
    }
  }

  void _openAuth(BuildContext context, {bool startInSignup = false}) {
    Navigator.push(
      context,
      PageTransitions.fade(AuthScreen(startInSignup: startInSignup)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: WandererTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHero(context, l10n),
              _buildFeatureGrid(context, l10n),
              _buildFinalCta(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                WandererTheme.primaryOrange.withOpacity(0.12),
                WandererTheme.primaryOrange.withOpacity(0.0),
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Row(
                children: [
                  const WandererLogo(size: 32),
                  const SizedBox(width: 8),
                  const Text(
                    'Wanderer',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: WandererTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  _PlayStoreBadge(
                    height: 40,
                    semanticLabel: l10n.landingInstallCta,
                    onTap: () => _openPlayStore(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                l10n.landingHeadline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: WandererTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.landingSubheadline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: WandererTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              _PlayStoreBadge(
                height: 50,
                semanticLabel: l10n.landingInstallCta,
                onTap: () => _openPlayStore(context),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: () => _openAuth(context, startInSignup: true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.getStarted,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _openAuth(context, startInSignup: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WandererTheme.primaryOrange,
                      side: BorderSide(
                        color: WandererTheme.primaryOrange.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.logIn,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _PhoneCollageWithBackdrop(),
      ],
    );
  }

  Widget _buildFeatureGrid(BuildContext context, AppLocalizations l10n) {
    final features = [
      (
        Icons.map_outlined,
        l10n.landingFeatureTrackingTitle,
        l10n.landingFeatureTrackingDesc,
      ),
      (
        Icons.people_outline,
        l10n.landingFeatureSocialTitle,
        l10n.landingFeatureSocialDesc,
      ),
      (
        Icons.route_outlined,
        l10n.landingFeaturePlanningTitle,
        l10n.landingFeaturePlanningDesc,
      ),
      (
        Icons.emoji_events_outlined,
        l10n.landingFeatureAchievementsTitle,
        l10n.landingFeatureAchievementsDesc,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 640;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: features
                .map((feature) => SizedBox(
                      width: isNarrow
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 2,
                      child: _FeatureCard(
                        icon: feature.$1,
                        title: feature.$2,
                        description: feature.$3,
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildFinalCta(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            WandererTheme.primaryOrange.withOpacity(0.0),
            WandererTheme.primaryOrange.withOpacity(0.12),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            l10n.landingHeadline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: WandererTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _PlayStoreBadge(
            height: 50,
            semanticLabel: l10n.landingInstallCta,
            onTap: () => _openPlayStore(context),
          ),
        ],
      ),
    );
  }
}

/// Official Google Play badge image, wrapped for tap + pointer cursor.
class _PlayStoreBadge extends StatelessWidget {
  final double height;
  final String semanticLabel;
  final VoidCallback onTap;

  const _PlayStoreBadge({
    required this.height,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Image.asset(
            'assets/images/google-play-badge.png',
            height: height,
          ),
        ),
      ),
    );
  }
}

/// Dims/fades a map screenshot behind the phone collage so it doesn't sit on
/// a flat, empty background.
class _PhoneCollageWithBackdrop extends StatelessWidget {
  const _PhoneCollageWithBackdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.25, 0.75, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Opacity(
                opacity: 0.25,
                child: Image.asset(
                  'assets/images/landing-route-backdrop.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const _PhoneCollage(),
        ],
      ),
    );
  }
}

/// Three overlapping, tilted phone mockups showing real in-app screenshots —
/// the "flashy" moment of the page. Purely decorative, no interaction.
class _PhoneCollage extends StatelessWidget {
  const _PhoneCollage();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.rotate(
          angle: -0.14,
          child: const _PhoneMockup(
            imagePath: 'assets/images/inApp/profile.jpeg',
            width: 150,
          ),
        ),
        Transform.translate(
          offset: const Offset(-24, 0),
          child: Transform.rotate(
            angle: 0,
            child: const _PhoneMockup(
              imagePath: 'assets/images/inApp/in_map.jpeg',
              width: 180,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(-48, 0),
          child: Transform.rotate(
            angle: 0.14,
            child: const _PhoneMockup(
              imagePath: 'assets/images/inApp/home.jpeg',
              width: 150,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  final String imagePath;
  final double width;

  const _PhoneMockup({required this.imagePath, required this.width});

  @override
  Widget build(BuildContext context) {
    final height = width * 2.15;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(imagePath,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity),
          ),
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: width * 0.3,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: WandererTheme.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hovering ? 0.12 : 0.06),
                blurRadius: _hovering ? 20 : 12,
                offset: Offset(0, _hovering ? 8 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WandererTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  color: WandererTheme.primaryOrange,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: WandererTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: WandererTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
