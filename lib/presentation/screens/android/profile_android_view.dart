import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wanderer_frontend/core/constants/api_endpoints.dart';
import 'package:wanderer_frontend/core/l10n/app_localizations.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/core/theme/wanderer_theme.dart';
import 'package:wanderer_frontend/data/client/api_client.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/presentation/helpers/page_transitions.dart';
import 'package:wanderer_frontend/presentation/screens/achievements_screen.dart';
import 'package:wanderer_frontend/presentation/screens/android/android_shell.dart';
import 'package:wanderer_frontend/presentation/screens/friends_followers_screen.dart';
import 'package:wanderer_frontend/presentation/screens/settings_screen.dart';
import 'package:wanderer_frontend/presentation/screens/trip_detail_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/android/android_ui.dart';
import 'package:wanderer_frontend/presentation/widgets/common/toasts.dart';
import 'package:wanderer_frontend/presentation/widgets/common/user_avatar.dart';
import 'package:wanderer_frontend/presentation/widgets/common/wanderer_sheet.dart';
import 'package:wanderer_frontend/presentation/widgets/profile/web_profile_widgets.dart';

/// Android profile (canvas: AndroidProfile). Own profile ([userId] null or
/// the current user) shows edit/share and the link list; someone else's
/// shows follow / friend buttons and their trips instead.
class ProfileAndroidView extends ConsumerStatefulWidget {
  final String? userId;

  /// Root of the You tab: no back arrow, "You" title.
  final bool isTab;

  const ProfileAndroidView({super.key, this.userId, this.isTab = false});

  @override
  ConsumerState<ProfileAndroidView> createState() => _ProfileAndroidViewState();
}

class _ProfileAndroidViewState extends ConsumerState<ProfileAndroidView> {
  UserProfile? _profile;
  String? _meId;
  bool _loading = true;
  String? _error;
  int _trips = 0, _followers = 0, _following = 0, _friends = 0;
  int _requests = 0, _unlocked = 0, _achievementTotal = 0;
  List<Trip> _userTrips = [];
  bool _isFollowing = false, _isFriend = false;
  String? _sentRequestId;

  bool get _own => widget.userId == null || widget.userId == _meId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(profileRepositoryProvider);
    final users = ref.read(userServiceProvider);
    try {
      final me = await repo.getMyProfile();
      _meId = me.id;
      if (_own) {
        final achievements = ref.read(achievementServiceProvider);
        final r = await Future.wait([
          repo.getMyTrips(page: 0, size: 1),
          users.getFollowers(page: 0, size: 1),
          users.getFollowing(page: 0, size: 1),
          users.getFriends(page: 0, size: 1),
          users.getReceivedFriendRequests(),
          achievements.getAllAchievements(),
          achievements.getMyAchievements(),
        ]);
        if (!mounted) return;
        setState(() {
          _profile = me;
          _trips = (r[0] as PageResponse).totalElements;
          _followers = (r[1] as PageResponse).totalElements;
          _following = (r[2] as PageResponse).totalElements;
          _friends = (r[3] as PageResponse).totalElements;
          _requests = (r[4] as List).length;
          _achievementTotal = (r[5] as List).length;
          _unlocked = (r[6] as List).length;
          _loading = false;
          _error = null;
        });
        return;
      }
      final id = widget.userId!;
      final r = await Future.wait([
        repo.getUserProfile(id),
        repo.getUserTrips(id, page: 0, size: 100),
        users.getUserFollowers(id, page: 0, size: 1),
        users.getUserFollowing(id, page: 0, size: 1),
        users.getUserFriends(id, page: 0, size: 1),
        users.getFollowing(page: 0, size: 100),
        users.getFriends(page: 0, size: 100),
        users.getSentFriendRequests(),
      ]);
      final trips = (r[1] as PageResponse<Trip>).content
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final sent = (r[7] as List<FriendRequest>)
          .where((q) =>
              q.receiverId == id && q.status == FriendRequestStatus.pending)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _profile = r[0] as UserProfile;
        _userTrips = trips;
        _trips = trips.length;
        _followers = (r[2] as PageResponse).totalElements;
        _following = (r[3] as PageResponse).totalElements;
        _friends = (r[4] as PageResponse).totalElements;
        _isFollowing = (r[5] as PageResponse<UserFollow>)
            .content
            .any((f) => f.followedId == id);
        _isFriend = (r[6] as PageResponse<Friendship>)
            .content
            .any((f) => f.friendId == id);
        _sentRequestId = sent?.id;
        _loading = false;
        _error = null;
      });
    } on AuthenticationRedirectException {
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, PageTransitions.slideRight(screen));
    if (mounted) _load();
  }

  void _toast(String title, [ToastKind kind = ToastKind.success]) =>
      Toasts.show(ToastData(kind: kind, title: title));

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      _toast(done);
      await _load();
    } catch (e) {
      _toast(e.toString(), ToastKind.error);
    }
  }

  void _toggleFollow() {
    final l10n = context.l10n;
    final users = ref.read(userServiceProvider);
    final p = _profile!;
    _run(
      () => _isFollowing ? users.unfollowUser(p.id) : users.followUser(p.id),
      _isFollowing
          ? l10n.unfollowedUser(p.username)
          : l10n.nowFollowingUser(p.username),
    );
  }

  void _toggleFriend() {
    final l10n = context.l10n;
    final users = ref.read(userServiceProvider);
    final p = _profile!;
    if (_isFriend) {
      _run(
          () => users.removeFriend(p.id), l10n.noLongerFriendsWith(p.username));
    } else if (_sentRequestId != null) {
      _run(() => users.deleteFriendRequest(_sentRequestId!),
          l10n.friendRequestCancelled);
    } else {
      _run(() => users.sendFriendRequest(p.id),
          l10n.friendRequestSentTo(p.username));
    }
  }

  void _share() {
    Clipboard.setData(ClipboardData(
        text: '${ApiEndpoints.appBaseUrl}/user/'
            '${Uri.encodeComponent(_profile!.username)}'));
    _toast(context.l10n.dialogsShareLinkCopied);
  }

  Future<void> _editProfile() async {
    final l10n = context.l10n;
    final name = TextEditingController(text: _profile!.displayName);
    final bio = TextEditingController(text: _profile!.bio);
    final save = await showWandererSheet<bool>(
      context,
      title: l10n.editProfile,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
              label: l10n.displayName,
              hint: l10n.yourDisplayName,
              controller: name,
              textInputAction: TextInputAction.next),
          const SizedBox(height: 16),
          LabeledField(
              label: l10n.bio,
              hint: l10n.tellUsAboutYourself,
              controller: bio,
              maxLines: 3),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: WandererTheme.trail,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
    );
    if (save == true) {
      final repo = ref.read(profileRepositoryProvider);
      await _run(() async {
        await repo.updateProfile(UpdateProfileRequest(
          displayName: name.text.isEmpty ? null : name.text,
          bio: bio.text.isEmpty ? null : bio.text,
        ));
        await repo.refreshUserDetails();
      }, l10n.profileUpdatedSuccessfully);
    }
    name.dispose();
    bio.dispose();
  }

  Future<void> _avatarSheet() async {
    final l10n = context.l10n;
    final action = await showWandererSheet<String>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.profileChangeAvatar),
            onTap: () => Navigator.pop(context, 'change'),
          ),
          ListTile(
            leading: const Icon(Icons.no_photography_outlined),
            title: Text(l10n.youDeleteAvatar),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );
    final repo = ref.read(profileRepositoryProvider);
    if (action == 'delete') {
      await _run(repo.deleteAvatar, l10n.profileUpdatedSuccessfully);
    } else if (action == 'change') {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final cropped = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: l10n.profileChangeAvatar,
            toolbarColor: WandererTheme.trail,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: WandererTheme.trail,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
          ),
        ],
      );
      if (cropped == null) return;
      final bytes = await cropped.readAsBytes();
      final name = cropped.path.split('/').last;
      await _run(
          () =>
              repo.uploadAvatar(bytes, name.contains('.') ? name : '$name.jpg'),
          l10n.profileUpdatedSuccessfully);
      // The new picture is served under the same URL; drop the cached one.
      NetworkImage(ApiEndpoints.resolveThumbnailUrl(_profile!.avatarUrl))
          .evict();
    }
  }

  Future<void> _supportWanderer() async {
    try {
      await launchUrl(Uri.parse('https://buymeacoffee.com/tomassirio'),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      _toast(e.toString(), ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = WandererTheme.of(context);
    final l10n = context.l10n;
    final gear = IconButton(
      tooltip: l10n.settings,
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => _push(const SettingsScreen()),
    );
    final PreferredSizeWidget appBar = widget.isTab
        ? AppBar(
            toolbarHeight: 64,
            backgroundColor: c.ground,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 20,
            title:
                Text(l10n.you, style: WandererTheme.display(24, color: c.text)),
            actions: [gear, const SizedBox(width: 4)],
          )
        : AndroidTopBar(
            title: _own ? l10n.you : (_profile?.username ?? ''),
            actions: _own ? [gear] : null,
          );

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_profile == null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error ?? l10n.noProfileData,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: Text(l10n.retry)),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _card(c, l10n),
            const SizedBox(height: 16),
            if (_own)
              _links(c, l10n)
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Text(l10n.trips,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.text)),
              ),
              if (_userTrips.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.noTripsYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textMuted)),
                ),
              for (final t in _userTrips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WebProfileTripCard(
                    trip: t,
                    onTap: () => _push(TripDetailScreen(trip: t)),
                  ),
                ),
            ],
          ],
        ),
      );
    }
    return Scaffold(backgroundColor: c.ground, appBar: appBar, body: body);
  }

  Widget _card(WandererColors c, AppLocalizations l10n) {
    final p = _profile!;
    final bio = p.bio ?? '';
    final social = _own ? () => _push(const FriendsFollowersScreen()) : null;
    final avatar = UserAvatar(
      userId: p.id,
      username: p.username,
      displayName: p.displayName,
      radius: 36,
      backgroundColor: c.forestBg,
      textColor: c.forestFg,
    );
    final outlined = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: c.text,
      side: BorderSide(color: c.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
    final buttons = _own
        ? [
            OutlinedButton(
                style: outlined,
                onPressed: _editProfile,
                child: Text(l10n.editProfile)),
            OutlinedButton(
                style: outlined,
                onPressed: _share,
                child: Text(l10n.youShareProfile)),
          ]
        : [
            _isFollowing
                ? OutlinedButton(
                    style: outlined,
                    onPressed: _toggleFollow,
                    child: Text(l10n.unfollow))
                : FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: WandererTheme.trail,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _toggleFollow,
                    child: Text(l10n.follow)),
            OutlinedButton(
                style: outlined,
                onPressed: _toggleFriend,
                child: Text(_isFriend
                    ? l10n.unfriend
                    : _sentRequestId != null
                        ? l10n.friendsCancelRequest
                        : l10n.friendsAddFriend)),
          ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: WandererTheme.cardDecoration(context, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _own
                ? InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _avatarSheet,
                    child: Tooltip(
                        message: l10n.profileChangeAvatar, child: avatar))
                : avatar,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName ?? p.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: WandererTheme.display(22, color: c.text)),
                  const SizedBox(height: 2),
                  Text('@${p.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: c.textMuted)),
                ],
              ),
            ),
          ]),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(bio,
                style: TextStyle(fontSize: 15, height: 1.5, color: c.text)),
          ],
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: c.lineSoft),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(children: [
                _stat(c, l10n.trips, _trips, null, first: true),
                _stat(c, l10n.followers, _followers, social),
                _stat(c, l10n.following, _following, social),
                _stat(c, l10n.friends, _friends, social),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: buttons[0]),
            const SizedBox(width: 8),
            Expanded(child: buttons[1]),
          ]),
        ],
      ),
    );
  }

  Widget _stat(WandererColors c, String label, int value, VoidCallback? onTap,
      {bool first = false}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            border: first ? null : Border(left: BorderSide(color: c.lineSoft)),
          ),
          child: Column(children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: c.text)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textMuted)),
          ]),
        ),
      ),
    );
  }

  Widget _links(WandererColors c, AppLocalizations l10n) {
    final rows = [
      (
        Icons.people_outline,
        c.trailSoftBg,
        WandererTheme.trail,
        l10n.friends,
        _requests == 0
            ? l10n.youNoRequestsWaiting
            : _requests == 1
                ? l10n.youOneRequestWaiting
                : l10n.youRequestsWaiting(_requests),
        () => _push(const FriendsFollowersScreen()),
      ),
      (
        Icons.emoji_events_outlined,
        c.goldBg,
        c.goldFg,
        l10n.achievements,
        l10n.achievementsUnlockedOf(_unlocked, _achievementTotal),
        () => _push(const AchievementsScreen()),
      ),
      (
        Icons.map_outlined,
        c.skyBg,
        c.skyFg,
        l10n.tripPlansTitle,
        l10n.youPlanRoutesAhead,
        () => AndroidShell.selectTab(context, AndroidTab.trips),
      ),
      (
        Icons.favorite_outline,
        c.forestBg,
        c.forestFg,
        l10n.navSupport,
        l10n.buyMeACoffee,
        _supportWanderer,
      ),
    ];
    return Container(
      decoration: WandererTheme.cardDecoration(context, radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: rows[i].$6,
              child: Container(
                constraints: const BoxConstraints(minHeight: 60),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: c.lineSoft)),
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: rows[i].$2,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(rows[i].$1, size: 20, color: rows[i].$3),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].$4,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: c.text)),
                        Text(rows[i].$5,
                            style: TextStyle(fontSize: 13, color: c.textMuted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: c.caption),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
