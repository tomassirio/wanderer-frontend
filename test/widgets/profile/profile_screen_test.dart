import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wanderer_frontend/core/providers/app_providers.dart';
import 'package:wanderer_frontend/data/client/websocket_client.dart'
    show WebSocketConnectionState;
import 'package:wanderer_frontend/data/models/responses/page_response.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/user_models.dart';
import 'package:wanderer_frontend/data/models/websocket/websocket_event.dart';
import 'package:wanderer_frontend/data/repositories/profile_repository.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';
import 'package:wanderer_frontend/data/services/websocket_service.dart';
import 'package:wanderer_frontend/presentation/screens/profile_screen.dart';
import 'package:wanderer_frontend/presentation/widgets/common/app_sidebar.dart';

const _meId = '11111111-aaaa-bbbb-cccc-000000000001';
const _otherId = '22222222-aaaa-bbbb-cccc-000000000002';

UserProfile _user(String id, String username) => UserProfile(
      id: id,
      username: username,
      email: '$username@example.com',
      followersCount: 0,
      followingCount: 0,
      tripsCount: 0,
      createdAt: DateTime(2024),
    );

PageResponse<T> _page<T>() => PageResponse<T>(
    content: [],
    totalElements: 0,
    totalPages: 0,
    number: 0,
    size: 0,
    first: true,
    last: true);

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<bool> isLoggedIn() async => true;
  @override
  Future<bool> isAdmin() async => false;
  @override
  Future<String?> getCurrentUserId() async => _meId;
  @override
  Future<UserProfile> getMyProfile() async => _user(_meId, 'me');
  @override
  Future<UserProfile> getUserProfile(String userId) async =>
      _user(userId, 'other');
  @override
  Future<PageResponse<Trip>> getMyTrips({int page = 0, int size = 20}) async =>
      _page();
  @override
  Future<PageResponse<Trip>> getUserTrips(String userId,
          {int page = 0, int size = 20}) async =>
      _page();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserService implements UserService {
  @override
  Future<PageResponse<UserFollow>> getFollowers(
          {int page = 0, int size = 20}) async =>
      _page();
  @override
  Future<PageResponse<UserFollow>> getFollowing(
          {int page = 0, int size = 20}) async =>
      _page();
  @override
  Future<PageResponse<Friendship>> getFriends(
          {int page = 0, int size = 20}) async =>
      _page();
  @override
  Future<PageResponse<UserFollow>> getUserFollowers(String userId,
          {int page = 0, int size = 20}) async =>
      _page();
  @override
  Future<PageResponse<UserFollow>> getUserFollowing(String userId,
          {int page = 0, int size = 20}) async =>
      _page();
  @override
  Future<PageResponse<Friendship>> getUserFriends(String userId,
          {int page = 0, int size = 20}) async =>
      _page();
  @override
  Future<List<FriendRequest>> getSentFriendRequests() async => [];
  @override
  Future<List<FriendRequest>> getReceivedFriendRequests() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebSocketService implements WebSocketService {
  @override
  Future<void> connect() async {}
  @override
  Stream<WebSocketEvent> subscribeToUser(String userId) => const Stream.empty();
  @override
  Stream<WebSocketEvent> get events => const Stream.empty();
  @override
  Stream<WebSocketConnectionState> get connectionState => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpProfile(WidgetTester tester, ProfileScreen screen) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        userServiceProvider.overrideWithValue(_FakeUserService()),
        websocketServiceProvider.overrideWithValue(_FakeWebSocketService()),
      ],
      child: MaterialApp(home: screen),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<int> sidebarIndex(WidgetTester tester) async {
    tester.firstState<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return tester.widget<AppSidebar>(find.byType(AppSidebar)).selectedIndex;
  }

  testWidgets('own profile keeps the user ID, Edit profile and My trips',
      (tester) async {
    await pumpProfile(tester, const ProfileScreen());
    expect(find.text(_meId), findsOneWidget);
    expect(find.byTooltip('Edit Profile'), findsOneWidget);
    expect(await sidebarIndex(tester), AppSidebar.myTripsIndex);
  });

  testWidgets('other profile hides the user ID and Edit profile',
      (tester) async {
    await pumpProfile(tester, const ProfileScreen(userId: _otherId));
    expect(find.text('@other'), findsOneWidget);
    expect(find.text(_otherId), findsNothing);
    expect(find.byTooltip('Edit Profile'), findsNothing);
  });

  testWidgets('opened from Explore highlights Explore', (tester) async {
    await pumpProfile(tester,
        const ProfileScreen(userId: _otherId, origin: ProfileOrigin.explore));
    expect(await sidebarIndex(tester), AppSidebar.exploreIndex);
  });

  testWidgets('opened from Friends highlights Friends', (tester) async {
    await pumpProfile(tester,
        const ProfileScreen(userId: _otherId, origin: ProfileOrigin.friends));
    expect(await sidebarIndex(tester), AppSidebar.friendsIndex);
  });

  testWidgets('deep link (no origin) defaults to Explore', (tester) async {
    // UserDeepLinkScreen builds ProfileScreen(userId: ...) without an origin.
    await pumpProfile(tester, const ProfileScreen(userId: _otherId));
    expect(await sidebarIndex(tester), AppSidebar.exploreIndex);
  });
}
