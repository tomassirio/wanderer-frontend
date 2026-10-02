import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/android_app_links.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';

class MobileWebAppBanner extends StatefulWidget {
  final String? tripId;
  const MobileWebAppBanner({super.key, this.tripId});

  @override
  State<MobileWebAppBanner> createState() => _MobileWebAppBannerState();
}

class _MobileWebAppBannerState extends State<MobileWebAppBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Material(
      color: c.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.only(right: 12),
          decoration:
              BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
          child: Row(children: [
            IconButton(
              tooltip: l10n.close,
              onPressed: () => setState(() => _dismissed = true),
              icon: Icon(Icons.close, size: 16, color: c.caption),
            ),
            const WandererLogo(size: 36),
            const SizedBox(width: 10),
            Expanded(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        widget.tripId == null
                            ? l10n.mobileWebAppTitle
                            : l10n.mobileWebFollowLive,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.text)),
                    Text(
                        widget.tripId == null
                            ? l10n.mobileWebAppSubtitle
                            : l10n.mobileWebFollowSubtitle,
                        style: TextStyle(fontSize: 11, color: c.caption)),
                  ]),
            )),
            TextButton(
              onPressed: () => AndroidAppLinks.open(context,
                  tripId: widget.tripId, install: widget.tripId == null),
              style: TextButton.styleFrom(
                backgroundColor: c.neutralButtonBg,
                foregroundColor: c.neutralButtonFg,
                shape: const StadiumBorder(),
              ),
              child: Text(widget.tripId == null
                  ? l10n.mobileWebGet
                  : l10n.mobileWebOpenApp),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The official "Get it on Google Play" badge as the button: no extra pill
/// around it (the badge carries its own black shape and border).
class MobileWebPlayButton extends StatelessWidget {
  const MobileWebPlayButton({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          button: true,
          label: context.l10n.landingInstallCta,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => AndroidAppLinks.open(context, install: true),
            child: Image.asset('assets/images/google-play-badge.png',
                height: 54, excludeFromSemantics: true),
          ),
        ),
      );
}

class MobileWebTrackingCard extends StatelessWidget {
  final String? tripId;
  final bool tracking;
  const MobileWebTrackingCard({super.key, this.tripId, this.tracking = true});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    if (tripId != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        decoration: BoxDecoration(
            color: c.skyBg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
              child: Text(
                  tracking
                      ? l10n.mobileWebTrackingRunning
                      : l10n.mobileWebTrackingNeedsApp,
                  style: TextStyle(fontSize: 13, color: c.skyFg))),
          TextButton(
            onPressed: () => AndroidAppLinks.open(context, tripId: tripId),
            child:
                Text(l10n.mobileWebOpenApp, style: TextStyle(color: c.skyFg)),
          ),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: WandererTheme.cardDecoration(context, radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const WandererLogo(size: 40),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(l10n.mobileWebTrackTitle,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
                Text(l10n.mobileWebTrackingNeedsApp,
                    style: TextStyle(fontSize: 13, color: c.textMuted)),
              ])),
        ]),
        const SizedBox(height: 12),
        const MobileWebPlayButton(),
      ]),
    );
  }
}

class MobileWebAppFooter extends StatelessWidget {
  const MobileWebAppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: WandererTheme.cardDecoration(context, radius: 14),
        child: Row(children: [
          const WandererLogo(size: 32),
          const SizedBox(width: 10),
          Expanded(
              child: Text(context.l10n.mobileWebHaveApp,
                  style: TextStyle(fontSize: 12, color: c.textMuted))),
          TextButton(
            onPressed: () => AndroidAppLinks.open(context),
            child: Text(context.l10n.mobileWebOpenApp),
          ),
        ]),
      ),
    );
  }
}
