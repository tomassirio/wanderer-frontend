import 'package:flutter/material.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_auth_widgets.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_logo.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';

class LandingFreeBadge extends StatelessWidget {
  const LandingFreeBadge({super.key});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Pill(context.l10n.landingFreeBadge, tone: PillTone.promoted),
        ),
      );
}

class LandingBrandHeader extends StatelessWidget {
  const LandingBrandHeader({super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
        const WandererLogo(size: 32),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Wanderer',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WandererTheme.display(20,
                  color: WandererTheme.of(context).text)),
        ),
        const AndroidAuthHeaderActions(),
      ]);
}

class LandingHeadline extends StatelessWidget {
  final double fontSize;
  const LandingHeadline({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: l10n.landingHeroBefore),
          TextSpan(
              text: l10n.landingHeroAccent,
              style: TextStyle(
                  color: identical(c, WandererColors.dark)
                      ? c.accentText
                      : WandererTheme.trail)),
          TextSpan(text: l10n.landingHeroAfter),
        ]),
        style: WandererTheme.display(fontSize, color: c.text)
            .copyWith(height: 1.04),
      ),
    );
  }
}

/// The same route and phone preview on desktop, mobile web and Android.
class LandingProductPreview extends StatelessWidget {
  const LandingProductPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.25,
      child: LayoutBuilder(builder: (context, box) {
        final c = WandererTheme.of(context);
        final phoneW = box.maxWidth * 0.36;
        return Stack(children: [
          Positioned(
            left: 0,
            top: box.maxHeight * 0.06,
            width: box.maxWidth * 0.84,
            height: box.maxHeight * 0.84,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(WandererTheme.radiusPanel),
                border: Border.all(color: c.line),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1F3C2814),
                      blurRadius: 60,
                      offset: Offset(0, 24)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.lineSoft))),
                    child: Row(children: [
                      for (final dot in const [
                        Color(0xFFE9A5A0),
                        Color(0xFFEFD28F),
                        Color(0xFFA9CDB3),
                      ]) ...[
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: dot, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                      ],
                    ]),
                  ),
                  Expanded(
                    child: Image.asset(
                      'assets/images/landing-route-backdrop.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerLeft,
                      excludeFromSemantics: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: phoneW,
            height: phoneW * 2.05,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.text,
                borderRadius: BorderRadius.circular(phoneW * 0.15),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x401B1A17),
                      blurRadius: 60,
                      offset: Offset(0, 24)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(phoneW * 0.12),
                child: Image.asset(
                  'assets/images/inApp/in_map.png',
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}
