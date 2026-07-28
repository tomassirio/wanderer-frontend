import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/presentation/helpers/ui_helpers.dart';

void main() {
  group('UiHelpers.getStatusColor', () {
    test('created is neutral grey', () {
      expect(UiHelpers.getStatusColor(TripStatus.created),
          const Color(0xFF6C757D));
    });

    test('inProgress is green', () {
      expect(UiHelpers.getStatusColor(TripStatus.inProgress),
          const Color(0xFF4CAF50));
    });

    test('paused is orange', () {
      expect(UiHelpers.getStatusColor(TripStatus.paused),
          const Color(0xFFFF9800));
    });

    test('finished reuses WandererTheme.statusCompleted', () {
      expect(UiHelpers.getStatusColor(TripStatus.finished),
          WandererTheme.statusCompleted);
    });

    test('resting reuses WandererTheme.statusResting', () {
      expect(UiHelpers.getStatusColor(TripStatus.resting),
          WandererTheme.statusResting);
    });
  });

  group('UiHelpers.getStatusIcon (unchanged, regression guard)', () {
    test('maps every status to its existing icon', () {
      expect(UiHelpers.getStatusIcon(TripStatus.created), Icons.schedule);
      expect(UiHelpers.getStatusIcon(TripStatus.inProgress), Icons.play_arrow);
      expect(UiHelpers.getStatusIcon(TripStatus.paused), Icons.pause);
      expect(UiHelpers.getStatusIcon(TripStatus.finished), Icons.check);
      expect(UiHelpers.getStatusIcon(TripStatus.resting),
          Icons.nightlight_round);
    });
  });

  group('UiHelpers.getVisibilityIcon', () {
    test('protected returns lock_outline (matching what the app already '
        'renders in home_screen.dart and VisibilityBadge, not the old '
        'disagreeing Icons.group)', () {
      expect(
        UiHelpers.getVisibilityIcon(Visibility.protected),
        Icons.lock_outline,
      );
    });

    test('public returns public, private returns lock', () {
      expect(UiHelpers.getVisibilityIcon(Visibility.public), Icons.public);
      expect(UiHelpers.getVisibilityIcon(Visibility.private), Icons.lock);
    });
  });
}
