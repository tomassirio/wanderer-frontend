import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/presentation/helpers/auth_navigation_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/date_format_helper.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';
import 'package:wanderer_frontend/presentation/strategies/trip_detail_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/widgets/common/pill.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_share_dialog.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/web_trip_detail_layout.dart';

/// Web view for the owner's not-yet-started trip: trips can only be started
/// from the Android app, so this points them at their phone instead of an
/// empty map.
class WebDraftTripView extends StatefulWidget {
  final TripDetailLayoutData data;

  /// Called by the × — the screen then shows the normal trip view.
  final VoidCallback onDismiss;

  const WebDraftTripView(
      {super.key, required this.data, required this.onDismiss});

  /// Owner, still a draft, nothing tracked yet, and not dismissed.
  static bool shouldShow(
          Trip trip, String? currentUserId, List<TripLocation> updates,
          {bool dismissed = false}) =>
      !dismissed &&
      currentUserId != null &&
      trip.userId == currentUserId &&
      trip.status == TripStatus.created &&
      updates.isEmpty &&
      (trip.updateCount ?? 0) == 0;

  static String dismissedKey(String tripId) =>
      'draft_start_hint_dismissed_$tripId';

  static Future<bool> isDismissed(String tripId) async =>
      (await SharedPreferences.getInstance()).getBool(dismissedKey(tripId)) ??
      false;

  static Future<void> setDismissed(String tripId) async =>
      (await SharedPreferences.getInstance())
          .setBool(dismissedKey(tripId), true);

  static Future<void> clearDismissed(String tripId) async =>
      (await SharedPreferences.getInstance()).remove(dismissedKey(tripId));

  /// Cap on the card's text column so body copy stays readable on very wide
  /// windows; the card itself stays fluid.
  static const double maxTextWidth = 560;

  @override
  State<WebDraftTripView> createState() => _WebDraftTripViewState();
}

class _WebDraftTripViewState extends State<WebDraftTripView> {
  Trip get _trip => widget.data.trip;
  String get _link => ApiEndpoints.tripDeepLink(_trip.id);

  String _visibilityLabel(AppLocalizations l10n, Visibility v) => switch (v) {
        Visibility.public => l10n.newTripPublic,
        Visibility.protected => l10n.newTripFriends,
        Visibility.private => l10n.privateVisibility,
      };

  void _openSettings() => showTripSettingsDialog(context, widget.data);

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _link));
    UiHelpers.showSuccessMessage(context, context.l10n.dialogsShareLinkCopied);
  }

  Future<void> _launch(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        UiHelpers.showErrorMessage(
            context, context.l10n.msgEmailClientUnavailable);
      }
    } catch (_) {
      if (mounted) {
        UiHelpers.showErrorMessage(
            context, context.l10n.msgEmailClientUnavailable);
      }
    }
  }

  // The user's email isn't stored client-side, so the recipient is left
  // empty and the mail app fills in the sender's own account.
  void _emailLink() {
    final l10n = context.l10n;
    _launch(Uri.parse('mailto:?subject='
        '${Uri.encodeComponent(l10n.draftTripEmailSubject(_trip.name))}'
        '&body=${Uri.encodeComponent(l10n.draftTripEmailBody(_link))}'));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final gutter = constraints.maxWidth >= 720 ? 40.0 : 16.0;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 28),
        child: LayoutBuilder(builder: (context, box) {
          final main = _buildMainCard(context);
          final side = _buildSide(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 22),
              // Board grid: minmax(0, 1fr) + 360px.
              if (box.maxWidth >= 1000)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: main),
                    const SizedBox(width: 20),
                    SizedBox(width: 360, child: side),
                  ],
                )
              else ...[
                main,
                const SizedBox(height: 16),
                side,
              ],
            ],
          );
        }),
      );
    });
  }

  Widget _buildHeader(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final d = widget.data;
    final created = DateFormatHelper.formatRelativeDate(l10n, _trip.createdAt);
    final createdLower = created.isEmpty
        ? created
        : created[0].toLowerCase() + created.substring(1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                InkWell(
                  onTap: () =>
                      AuthNavigationHelper.navigateToOwnProfile(context),
                  child: Text(l10n.myTrips,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textMuted)),
                ),
                Text('  /  ', style: TextStyle(fontSize: 13, color: c.caption)),
                Flexible(
                  child: Text(_trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.text)),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(_trip.name, style: WandererTheme.display(32)),
                  ),
                  Pill.status(context, _trip.status),
                  Pill(_visibilityLabel(l10n, _trip.visibility)),
                ],
              ),
              const SizedBox(height: 8),
              Text(l10n.draftTripCreated(createdLower),
                  style: TextStyle(fontSize: 14, color: c.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Row(mainAxisSize: MainAxisSize.min, children: [
          _buildMoreMenu(context),
          const SizedBox(width: 10),
          OutlinedButton(
            key: d.settingsPanelKey,
            onPressed: _openSettings,
            child: Text(l10n.draftTripEdit),
          ),
        ]),
      ],
    );
  }

  /// The actions the regular web header offers a draft: share, change
  /// visibility and (via the settings handler) delete.
  Widget _buildMoreMenu(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final d = widget.data;
    return PopupMenuButton<String>(
      tooltip: l10n.draftTripMoreOptions,
      onSelected: (v) {
        if (v == 'share') {
          TripShareDialog.show(context, tripId: _trip.id, tripName: _trip.name);
        } else if (v == 'delete') {
          d.onDeleteTrip?.call();
        } else {
          final vis = Visibility.values.byName(v);
          if (vis != _trip.visibility) d.onVisibilityChange?.call(vis);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'share',
          child: Row(children: [
            const Icon(Icons.share_outlined, size: 18),
            const SizedBox(width: 10),
            Text(l10n.shareTrip),
          ]),
        ),
        if (d.onVisibilityChange != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            enabled: false,
            height: 32,
            child: Text(l10n.changeVisibility,
                style: TextStyle(fontSize: 12, color: c.caption)),
          ),
          for (final v in Visibility.values)
            PopupMenuItem(
              value: v.name,
              child: Row(children: [
                Icon(UiHelpers.getVisibilityIcon(v), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_visibilityLabel(l10n, v))),
                if (v == _trip.visibility) const Icon(Icons.check, size: 18),
              ]),
            ),
        ],
        if (d.onDeleteTrip != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline,
                  size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 10),
              Text(l10n.deleteTrip,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ]),
          ),
        ],
      ],
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(WandererTheme.radiusControl),
        ),
        child: Icon(Icons.more_vert, size: 18, color: c.textMuted),
      ),
    );
  }

  Widget _buildMainCard(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Container(
      decoration: WandererTheme.cardDecoration(context, radius: 22),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: LayoutBuilder(builder: (context, box) {
              final text = _buildSteps(context);
              final qr = SizedBox(width: 170, child: _buildQrColumn(context));
              // On short (very wide) cards the QR column is the tallest
              // item; keep its top clear of the × in the corner.
              final qrClear =
                  Padding(padding: const EdgeInsets.only(top: 24), child: qr);
              // Board: 150px | 1fr | 170px, 32px gaps, vertically centred.
              if (box.maxWidth >= 560) {
                return Row(children: [
                  const SizedBox(
                      width: 150,
                      height: 250,
                      child: CustomPaint(painter: _PhonePainter())),
                  const SizedBox(width: 32),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: WebDraftTripView.maxTextWidth),
                        child: text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  qrClear,
                ]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [text, const SizedBox(height: 24), Center(child: qr)],
              );
            }),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: IconButton(
              tooltip: l10n.draftTripHide,
              onPressed: widget.onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              icon: Icon(Icons.close, size: 16, color: c.caption),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final steps = [
      (l10n.draftTripStep1Bold, l10n.draftTripStep1Rest(_trip.username)),
      (l10n.draftTripStep2Bold, l10n.draftTripStep2Rest),
      (l10n.draftTripStep3Bold, l10n.draftTripStep3Rest),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pill(l10n.draftTripNextStep, tone: PillTone.promoted),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(l10n.draftTripTitle,
              style: WandererTheme.display(28).copyWith(height: 1.15)),
        ),
        const SizedBox(height: 16),
        Text(l10n.draftTripBody,
            style: TextStyle(fontSize: 15, height: 1.55, color: c.textMuted)),
        for (var i = 0; i < steps.length; i++) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.neutralButtonBg, shape: BoxShape.circle),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.neutralButtonFg)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: steps[i].$1,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: c.text)),
                    TextSpan(text: steps[i].$2),
                  ]),
                  style:
                      TextStyle(fontSize: 15, height: 1.45, color: c.textMuted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildQrColumn(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white, // QR needs a light quiet zone in dark mode too
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Semantics(
            label: l10n.draftTripQrLabel,
            image: true,
            child: QrImageView(
              data: _link,
              version: QrVersions.auto,
              size: 126,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.draftTripScan,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: c.caption)),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: l10n.landingInstallCta,
          child: InkWell(
            onTap: () => _launch(Uri.parse(ApiEndpoints.playStoreUrl)),
            child:
                Image.asset('assets/images/google-play-badge.png', width: 170),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _emailLink,
          style: TextButton.styleFrom(
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          child: Text(l10n.draftTripEmailMe),
        ),
      ],
    );
  }

  Widget _buildSide(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    const title = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 14, color: c.caption))),
            Text(value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        );
    final modality = _trip.tripModality;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: WandererTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.tripSettings, style: title),
              if (modality != null)
                row(
                    l10n.newTripLength,
                    modality == TripModality.multiDay
                        ? l10n.newTripMultiDay
                        : l10n.newTripSingleDay),
              row(l10n.newTripVisibleTo,
                  _visibilityLabel(l10n, _trip.visibility)),
              row(
                  l10n.draftTripAutoCheckIn,
                  _trip.automaticUpdates
                      ? l10n.newTripEvery(l10n
                          .newTripMinutes(_trip.effectiveUpdateRefresh ~/ 60))
                      : l10n.newTripOff),
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: _openSettings,
                child: Text(l10n.draftTripChangeSettings),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: WandererTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.draftTripInviteTitle, style: title),
              const SizedBox(height: 10),
              Text(l10n.draftTripInviteBody,
                  style:
                      TextStyle(fontSize: 14, height: 1.5, color: c.textMuted)),
              const SizedBox(height: 10),
              OutlinedButton(
                key: widget.data.shareButtonKey,
                onPressed: _copyLink,
                child: Text(l10n.draftTripCopyLink),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Phone showing a route ending at a live dot, after the design board's
/// illustration (fixed colours: it's a picture, not UI chrome).
class _PhonePainter extends CustomPainter {
  const _PhonePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 150, size.height / 250);
    void rrect(Rect r, double radius, Color color) => canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius)),
        Paint()..color = color);
    const sky = Color(0xFF2F5C8A);

    rrect(const Rect.fromLTWH(4, 4, 142, 242), 26, const Color(0xFF1B1A17));
    rrect(const Rect.fromLTWH(12, 14, 126, 222), 19, const Color(0xFFECE7DB));
    canvas.drawPath(
        Path()
          ..moveTo(12, 150)
          ..cubicTo(40, 140, 60, 170, 90, 160)
          ..cubicTo(120, 150, 130, 140, 138, 150)
          ..lineTo(138, 236)
          ..lineTo(12, 236)
          ..close(),
        Paint()..color = const Color(0xFFD5E3E0));
    canvas.drawPath(
        Path()
          ..moveTo(105, 60)
          ..cubicTo(95, 90, 90, 110, 75, 130)
          ..cubicTo(60, 150, 45, 160, 38, 180),
        Paint()
          ..color = sky
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(
        const Offset(38, 180), 15, Paint()..color = sky.withOpacity(0.2));
    canvas.drawCircle(
        const Offset(38, 180), 8.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(38, 180), 7, Paint()..color = sky);
    rrect(const Rect.fromLTWH(12, 186, 126, 50), 14, Colors.white);
    rrect(const Rect.fromLTWH(22, 198, 70, 8), 4,
        const Color(0xFF1B1A17).withOpacity(0.8));
    rrect(const Rect.fromLTWH(22, 212, 106, 16), 8, WandererTheme.trail);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
