// One-off migration tool for Phase 1 of the standards refactor.
//
// Run with: flutter test test/tool/generate_translation_assets_test.dart
// It writes assets/translations/{en,es,fr,nl}.json from the CURRENT
// hardcoded AppLocalizations implementation. Inspect the output, commit it,
// then delete this file and lib/core/l10n/translations/translations_*.dart
// together in Task 1.5 — this script has no purpose once its inputs are gone.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/l10n/translations/translations_en.dart';
import 'package:wanderer_frontend/core/l10n/translations/translations_es.dart';
import 'package:wanderer_frontend/core/l10n/translations/translations_fr.dart';
import 'package:wanderer_frontend/core/l10n/translations/translations_nl.dart';
import 'package:wanderer_frontend/data/models/domain/achievement_category.dart';

const _flatMaps = {
  'en': translationsEn,
  'es': translationsEs,
  'fr': translationsFr,
  'nl': translationsNl,
};

// Sentinel values substituted into method calls, then replaced with named
// placeholders in the captured output. Chosen to be extremely unlikely to
// collide with real translated text.
const _intA = 947;
const _intB = 813;
const _emailToken = 'PLACEHOLDER_EMAIL_TOKEN';
const _usernameToken = 'PLACEHOLDER_USERNAME_TOKEN';
const _dateToken = 'PLACEHOLDER_DATE_TOKEN';
const _errorToken = 'PLACEHOLDER_ERROR_TOKEN';

String _sub(String rendered, Map<String, String> literalToPlaceholder) {
  var out = rendered;
  literalToPlaceholder.forEach((literal, placeholder) {
    out = out.replaceAll(literal, placeholder);
  });
  return out;
}

Map<String, dynamic> _buildLocaleJson(String code) {
  final l10n = AppLocalizations(code);
  final out = <String, dynamic>{..._flatMaps[code]!};

  out['minutesAgo'] = _sub(l10n.minutesAgo(_intA), {'947': '{n}'});
  out['hoursAgo'] = _sub(l10n.hoursAgo(_intA), {'947': '{n}'});
  out['daysAgo'] = _sub(l10n.daysAgo(_intA), {'947': '{n}'});
  out['weeksAgo'] = _sub(l10n.weeksAgo(_intA), {'947': '{n}'});
  out['monthsAgo'] = _sub(l10n.monthsAgo(_intA), {'947': '{n}'});
  out['startsInDays'] = _sub(l10n.startsInDays(_intA), {'947': '{days}'});
  out['dayNumber'] = _sub(l10n.dayNumber(_intA), {'947': '{day}'});
  out['dayNStarted'] = _sub(l10n.dayNStarted(_intA), {'947': '{day}'});
  out['dayNEnded'] = _sub(l10n.dayNEnded(_intA), {'947': '{day}'});
  out['achievementDays'] = _sub(l10n.achievementDays(_intA), {'947': '{v}'});
  out['easterEggTapsRemaining'] =
      _sub(l10n.easterEggTapsRemaining(_intA), {'947': '{remaining}'});
  out['daysAgoShort'] = _sub(l10n.daysAgoShort(_intA), {'947': '{days}'});
  out['hoursAgoShort'] = _sub(l10n.hoursAgoShort(_intA), {'947': '{hours}'});
  out['minutesAgoShort'] =
      _sub(l10n.minutesAgoShort(_intA), {'947': '{minutes}'});

  out['passwordResetEmailSent'] =
      _sub(l10n.passwordResetEmailSent(_emailToken), {_emailToken: '{email}'});
  out['unfollowedUser'] =
      _sub(l10n.unfollowedUser(_usernameToken), {_usernameToken: '{username}'});
  out['nowFollowingUser'] = _sub(
      l10n.nowFollowingUser(_usernameToken), {_usernameToken: '{username}'});
  out['noLongerFriendsWith'] = _sub(
      l10n.noLongerFriendsWith(_usernameToken), {_usernameToken: '{username}'});
  out['friendRequestSentTo'] = _sub(
      l10n.friendRequestSentTo(_usernameToken), {_usernameToken: '{username}'});
  out['failedToFollowUser'] =
      _sub(l10n.failedToFollowUser(_errorToken), {_errorToken: '{error}'});
  out['failedToUnfollowUser'] =
      _sub(l10n.failedToUnfollowUser(_errorToken), {_errorToken: '{error}'});
  out['failedToAcceptFriendRequest'] = _sub(
      l10n.failedToAcceptFriendRequest(_errorToken), {_errorToken: '{error}'});
  out['failedToDeclineFriendRequest'] = _sub(
      l10n.failedToDeclineFriendRequest(_errorToken), {_errorToken: '{error}'});
  out['sentDateLabel'] =
      _sub(l10n.sentDateLabel(_dateToken), {_dateToken: '{date}'});

  out['achievementsProgress'] = _sub(
    l10n.achievementsProgress(_intA, _intB),
    {'947': '{unlocked}', '813': '{total}'},
  );
  out['achievedValue'] =
      _sub(l10n.achievedValue(_dateToken), {_dateToken: '{value}'});
  out['unlockedOn'] = _sub(l10n.unlockedOn(_dateToken), {_dateToken: '{date}'});
  out['goalValue'] = _sub(l10n.goalValue(_dateToken), {_dateToken: '{value}'});

  out['tripCountLabel_one'] = l10n.tripCountLabel(1);
  out['tripCountLabel_other'] =
      _sub(l10n.tripCountLabel(_intA), {'947': '{count}'});
  out['achievementUpdatesCount_one'] = l10n.achievementUpdatesCount(1);
  out['achievementUpdatesCount_other'] =
      _sub(l10n.achievementUpdatesCount(_intA), {'947': '{v}'});
  out['achievementFollowers_one'] = l10n.achievementFollowers(1);
  out['achievementFollowers_other'] =
      _sub(l10n.achievementFollowers(_intA), {'947': '{v}'});
  out['achievementFriends_one'] = l10n.achievementFriends(1);
  out['achievementFriends_other'] =
      _sub(l10n.achievementFriends(_intA), {'947': '{v}'});

  final names = <String, String>{};
  final descriptions = <String, String>{};
  for (final type in AchievementType.values) {
    final key = type.toJson();
    names[key] = l10n.achievementNameFor(key);
    descriptions[key] = l10n.achievementDescriptionFor(key);
  }
  out['achievementNames'] = names;
  out['achievementDescriptions'] = descriptions;

  return out;
}

void main() {
  test('generate assets/translations/*.json from current hardcoded strings',
      () {
    const encoder = JsonEncoder.withIndent('  ');
    for (final code in _flatMaps.keys) {
      final data = _buildLocaleJson(code);

      final file = File('assets/translations/$code.json');
      file.createSync(recursive: true);
      file.writeAsStringSync('${encoder.convert(data)}\n');

      for (final key in _flatMaps[code]!.keys) {
        expect(data.containsKey(key), isTrue, reason: '$code missing $key');
      }
      for (final t in AchievementType.values) {
        expect(
            (data['achievementNames'] as Map).containsKey(t.toJson()), isTrue);
        expect((data['achievementDescriptions'] as Map).containsKey(t.toJson()),
            isTrue);
      }
    }
  });
}
