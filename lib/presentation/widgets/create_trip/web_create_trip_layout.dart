import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/widgets/common/web_page_header.dart';

/// Web "Start a new trip" page: numbered form sections on the left and a
/// sticky summary card on the right. All state lives in the screen.
class WebCreateTripLayout extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TripModality modality;
  final ValueChanged<TripModality> onModalityChanged;
  final Visibility visibility;
  final ValueChanged<Visibility> onVisibilityChanged;
  final bool automaticUpdates;
  final ValueChanged<bool> onAutomaticUpdatesChanged;
  final int intervalMinutes;
  final ValueChanged<int> onIntervalChanged;
  final bool isLoading;
  final bool isLoggedIn;
  final String? userId;
  final VoidCallback onCreate;
  final VoidCallback onCancel;
  final VoidCallback onFromPlan;

  // Coach-mark targets (see CreateTripScreen tutorial).
  final Key? titleKey;
  final Key? tripTypeKey;
  final Key? visibilityKey;
  final Key? autoUpdatesKey;
  final Key? createButtonKey;

  const WebCreateTripLayout({
    super.key,
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.modality,
    required this.onModalityChanged,
    required this.visibility,
    required this.onVisibilityChanged,
    required this.automaticUpdates,
    required this.onAutomaticUpdatesChanged,
    required this.intervalMinutes,
    required this.onIntervalChanged,
    required this.isLoading,
    required this.onCreate,
    required this.onCancel,
    required this.onFromPlan,
    this.isLoggedIn = true,
    this.userId,
    this.titleKey,
    this.tripTypeKey,
    this.visibilityKey,
    this.autoUpdatesKey,
    this.createButtonKey,
  });

  static const intervals = [15, 30, 60, 120];

  static String intervalLabel(AppLocalizations l10n, int minutes) =>
      minutes < 60
          ? l10n.newTripMinutes(minutes)
          : l10n.newTripHours(minutes ~/ 60);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 1000;
      final gutter = box.maxWidth >= 720 ? 40.0 : 16.0;
      final form = Form(key: formKey, child: _sections(context));
      if (!wide) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 24),
              form,
              const SizedBox(height: 24),
              _summary(context),
            ],
          ),
        );
      }
      return Padding(
        padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: form,
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: _summary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _header(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final crumb = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: c.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onCancel,
              child: Text(l10n.navMyTrips, style: crumb),
            ),
            Text('  /  ', style: crumb),
            Text(l10n.newTripBreadcrumb, style: crumb.copyWith(color: c.text)),
          ],
        ),
        const SizedBox(height: 8),
        WebPageHeader(
          title: l10n.newTripPageTitle,
          isLoggedIn: isLoggedIn,
          userId: userId,
          actions: [
            _Segmented(
              labels: [l10n.newTripFromScratch, l10n.newTripFromPlan],
              selected: 0,
              onSelect: (i) {
                if (i == 1) onFromPlan();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _sections(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final label =
        TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          number: 1,
          title: l10n.newTripBasics,
          children: [
            Text(l10n.newTripName, style: label),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: titleKey,
              child: TextFormField(
                controller: titleController,
                style: TextStyle(fontSize: 15, color: c.text),
                decoration: InputDecoration(
                  hintText: l10n.newTripNameHint,
                  constraints: const BoxConstraints(minHeight: 48),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.newTripNameRequired
                    : null,
              ),
            ),
            const SizedBox(height: 18),
            Text.rich(
              TextSpan(text: '${l10n.newTripDescription} ', children: [
                TextSpan(
                  text: l10n.newTripOptional,
                  style: TextStyle(
                      fontWeight: FontWeight.w500, color: c.textMuted),
                ),
              ]),
              style: label,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: descriptionController,
              style: TextStyle(fontSize: 15, color: c.text),
              decoration:
                  InputDecoration(hintText: l10n.newTripDescriptionHint),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 18),
            Text(l10n.newTripHowLong, style: label),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: tripTypeKey,
              child: _grid(context, [
                for (final (m, icon, name, caption) in [
                  (
                    TripModality.simple,
                    Icons.wb_sunny_outlined,
                    l10n.newTripSingleDay,
                    l10n.newTripSingleDayCaption
                  ),
                  (
                    TripModality.multiDay,
                    Icons.luggage_outlined,
                    l10n.newTripMultiDay,
                    l10n.newTripMultiDayCaption
                  ),
                ])
                  _ChoiceCard(
                    selected: modality == m,
                    onTap: () => onModalityChanged(m),
                    icon: icon,
                    title: name,
                    caption: caption,
                  ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Section(
          number: 2,
          title: l10n.newTripWhoCanSee,
          children: [
            KeyedSubtree(
              key: visibilityKey,
              child: _grid(context, [
                for (final v in Visibility.values)
                  _ChoiceCard(
                    selected: visibility == v,
                    onTap: () => onVisibilityChanged(v),
                    title: visibilityName(l10n, v),
                    caption: _visibilityCaption(l10n, v),
                  ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 20),
        KeyedSubtree(
          key: autoUpdatesKey,
          child: _Section(
            number: 3,
            title: l10n.newTripLocationSharing,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.newTripAutoUpdates,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: c.text)),
                        const SizedBox(height: 2),
                        Text(l10n.newTripAutoUpdatesCaption,
                            style: TextStyle(fontSize: 13, color: c.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Switch(
                    value: automaticUpdates,
                    onChanged: onAutomaticUpdatesChanged,
                    activeColor: Colors.white,
                    activeTrackColor: WandererTheme.trail,
                  ),
                ],
              ),
              if (automaticUpdates) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.newTripSendEvery, style: label),
                      _Segmented(
                        compact: true,
                        labels: [
                          for (final m in intervals) intervalLabel(l10n, m)
                        ],
                        selected: intervals.indexOf(intervalMinutes),
                        onSelect: (i) => onIntervalChanged(intervals[i]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.newTripIntervalNote,
                    style: TextStyle(fontSize: 12, color: c.caption)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Equal-width cards in a row; stacks under 560px.
  Widget _grid(BuildContext context, List<Widget> cards) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              cards[i],
            ],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      );
    });
  }

  Widget _summary(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final muted = TextStyle(fontSize: 14, color: c.textMuted);
    final strong =
        TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text);
    Widget row(String k, String v) => Row(
          children: [
            Text(k, style: muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(v, style: strong, textAlign: TextAlign.end),
            ),
          ],
        );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: WandererTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 150,
            color: c.mapGround,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, color: c.caption, size: 28),
                const SizedBox(height: 6),
                Text(l10n.newTripRoutePlaceholder,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.caption)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.newTripSummary.toUpperCase(),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.96,
                        color: c.label)),
                const SizedBox(height: 14),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: titleController,
                  builder: (context, value, _) {
                    final name = value.text.trim();
                    return Text(
                      name.isEmpty ? l10n.newTripUntitled : name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: WandererTheme.display(20,
                          color: name.isEmpty ? c.caption : c.text),
                    );
                  },
                ),
                const SizedBox(height: 14),
                row(
                    l10n.newTripLength,
                    modality == TripModality.simple
                        ? l10n.newTripSingleDay
                        : l10n.newTripMultiDay),
                const SizedBox(height: 10),
                row(l10n.newTripVisibleTo, visibilityName(l10n, visibility)),
                const SizedBox(height: 10),
                row(
                    l10n.newTripAutoUpdatesShort,
                    automaticUpdates
                        ? l10n
                            .newTripEvery(intervalLabel(l10n, intervalMinutes))
                        : l10n.newTripOff),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    key: createButtonKey,
                    onPressed: isLoading ? null : onCreate,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(l10n.newTripCreate),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: isLoading ? null : onCancel,
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String visibilityName(AppLocalizations l10n, Visibility v) =>
      switch (v) {
        Visibility.public => l10n.newTripPublic,
        Visibility.protected => l10n.newTripFriends,
        Visibility.private => l10n.newTripPrivate,
      };

  static String _visibilityCaption(AppLocalizations l10n, Visibility v) =>
      switch (v) {
        Visibility.public => l10n.newTripPublicCaption,
        Visibility.protected => l10n.newTripFriendsCaption,
        Visibility.private => l10n.newTripPrivateCaption,
      };
}

class _Section extends StatelessWidget {
  final int number;
  final String title;
  final List<Widget> children;

  const _Section(
      {required this.number, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: WandererTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: c.text, shape: BoxShape.circle),
                child: Text('$number',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.surface)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: c.text)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

/// Selectable card with a radio dot; optional icon tile on the left.
class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String title;
  final String caption;

  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.caption,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final radius = BorderRadius.circular(WandererTheme.radiusCard);
    final radio = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? WandererTheme.trail : c.line,
          width: selected ? 6 : 2,
        ),
      ),
    );
    final titleText = Text(title,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: c.text));
    final captionText = Text(caption,
        style: TextStyle(fontSize: 13, height: 1.4, color: c.textMuted));

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? WandererTheme.trail.withOpacity(0.05)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? WandererTheme.trail : c.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: icon == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Expanded(child: titleText), radio]),
                      const SizedBox(height: 6),
                      captionText,
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected ? c.trailSoftBg : c.raised,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon,
                            color: selected ? c.trailSoftFg : c.textMuted),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleText,
                            const SizedBox(height: 2),
                            captionText
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      radio,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Pill-track segmented control: selected segment on the card surface.
class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool compact;

  const _Segmented({
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    // Scrolls sideways instead of overflowing on narrow screens.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _track(c),
    );
  }

  Widget _track(WandererColors c) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.neutralBg,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Semantics(
              button: true,
              selected: i == selected,
              child: Material(
                color: i == selected ? c.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(compact ? 8 : 9),
                child: InkWell(
                  onTap: () => onSelect(i),
                  borderRadius: BorderRadius.circular(compact ? 8 : 9),
                  child: Container(
                    height: compact ? 34 : 40,
                    padding:
                        EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight:
                            i == selected ? FontWeight.w700 : FontWeight.w600,
                        color: i == selected ? c.text : c.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
