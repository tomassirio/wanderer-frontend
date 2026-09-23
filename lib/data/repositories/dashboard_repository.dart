import 'package:flutter/foundation.dart';
import 'package:wanderer_frontend/data/models/domain/friend_request.dart';
import 'package:wanderer_frontend/data/models/domain/user_achievement.dart';
import 'package:wanderer_frontend/data/models/domain/user_profile.dart';
import 'package:wanderer_frontend/data/models/domain/comment.dart';
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/services/achievement_service.dart';
import 'package:wanderer_frontend/data/services/comment_service.dart';
import 'package:wanderer_frontend/data/services/trip_service.dart';
import 'package:wanderer_frontend/data/services/user_service.dart';

/// A pending friend request with the sender's profile resolved.
class DashboardFriendRequest {
  final FriendRequest request;
  final UserProfile sender;
  const DashboardFriendRequest(this.request, this.sender);
}

/// Everything the web home dashboard shows, loaded in one go.
class DashboardData {
  final UserProfile profile;

  /// The user's trips, most recently updated first.
  final List<Trip> trips;
  final List<UserAchievement> achievements;
  final List<DashboardFriendRequest> friendRequests;
  final int friendRequestCount;

  /// Comments other people left on the user's trips, newest first.
  final List<Comment> recentComments;

  /// Achievements unlocked on [latestTrip].
  final int latestTripAchievements;

  const DashboardData({
    required this.profile,
    required this.trips,
    required this.achievements,
    required this.friendRequests,
    required this.friendRequestCount,
    required this.recentComments,
    required this.latestTripAchievements,
  });

  Trip? get latestTrip => trips.isEmpty ? null : trips.first;

  double get longestTripKm => trips.fold(
      0,
      (max, t) =>
          (t.accruedDistanceKm ?? 0) > max ? t.accruedDistanceKm! : max);

  /// Newest achievements first.
  List<UserAchievement> get recentAchievements =>
      [...achievements]..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
}

/// Repository composing the services the web home dashboard needs.
class DashboardRepository {
  final TripService _tripService;
  final UserService _userService;
  final AchievementService _achievementService;
  final CommentService _commentService;

  /// How many of the latest trips to scan for recent comments.
  static const int commentTripsToScan = 3;

  DashboardRepository({
    TripService? tripService,
    UserService? userService,
    AchievementService? achievementService,
    CommentService? commentService,
  })  : _tripService = tripService ?? TripService(),
        _userService = userService ?? UserService(),
        _achievementService = achievementService ?? AchievementService(),
        _commentService = commentService ?? CommentService();

  Future<DashboardData> load() async {
    final profileF = _userService.getMyProfile();
    final tripsF = _tripService.getMyTrips(size: 50);
    final achievementsF = _optional(_achievementService.getMyAchievements());
    final requestsF = _optional(_userService.getReceivedFriendRequests());

    final profile = await profileF;
    final trips = [...(await tripsF).content]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final achievements = await achievementsF ?? const <UserAchievement>[];
    final requests = (await requestsF ?? const <FriendRequest>[])
        .where((r) => r.status == FriendRequestStatus.pending)
        .toList();

    final results = await Future.wait([
      _resolveSenders(requests.take(3)),
      _recentComments(trips, profile.id),
      trips.isEmpty
          ? Future.value(0)
          : _optional(_achievementService.getTripAchievements(trips.first.id))
              .then((list) => list?.length ?? 0),
    ]);

    return DashboardData(
      profile: profile,
      trips: trips,
      achievements: achievements,
      friendRequests: results[0] as List<DashboardFriendRequest>,
      friendRequestCount: requests.length,
      recentComments: results[1] as List<Comment>,
      latestTripAchievements: results[2] as int,
    );
  }

  Future<void> acceptFriendRequest(String requestId) =>
      _userService.acceptFriendRequest(requestId);

  Future<void> declineFriendRequest(String requestId) =>
      _userService.deleteFriendRequest(requestId);

  Future<List<DashboardFriendRequest>> _resolveSenders(
      Iterable<FriendRequest> requests) async {
    final resolved = await Future.wait(requests.map((r) async {
      final sender = await _optional(_userService.getUserById(r.senderId));
      return sender == null ? null : DashboardFriendRequest(r, sender);
    }));
    return resolved.whereType<DashboardFriendRequest>().toList();
  }

  Future<List<Comment>> _recentComments(List<Trip> trips, String myId) async {
    final withComments =
        trips.where((t) => t.commentsCount > 0).take(commentTripsToScan);
    final pages = await Future.wait(withComments.map(
        (t) => _optional(_commentService.getCommentsByTripId(t.id, size: 5))));
    return mergeRecentComments(
      pages.map((p) => p?.content ?? const <Comment>[]),
      excludeUserId: myId,
    );
  }

  /// Merges comment lists, drops [excludeUserId]'s own comments and keeps the
  /// [limit] newest.
  @visibleForTesting
  static List<Comment> mergeRecentComments(
    Iterable<List<Comment>> lists, {
    required String excludeUserId,
    int limit = 3,
  }) {
    final all = lists
        .expand((l) => l)
        .where((c) => c.userId != excludeUserId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(limit).toList();
  }

  /// A failing secondary section must not blank the whole dashboard.
  static Future<T?> _optional<T>(Future<T> future) async {
    try {
      return await future;
    } catch (e) {
      debugPrint('DashboardRepository: optional section failed: $e');
      return null;
    }
  }
}
