import 'package:flutter/material.dart' hide Visibility;
import 'package:wanderer_frontend/data/models/trip_models.dart';
import 'package:wanderer_frontend/data/models/comment_models.dart';
import 'package:wanderer_frontend/data/models/achievement_models.dart';
import 'package:wanderer_frontend/core/constants/enums.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/comments_section.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_info_card.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_settings_panel.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/timeline_panel.dart';
import 'package:wanderer_frontend/presentation/widgets/trip_detail/trip_update_panel.dart';
import 'package:wanderer_frontend/presentation/strategies/mobile_layout_strategy.dart';
import 'package:wanderer_frontend/presentation/strategies/desktop_layout_strategy.dart';

/// Data class containing all state and callbacks needed by layout strategies
class TripDetailLayoutData {
  final Trip trip;
  final List<Comment> comments;
  final Map<String, List<Comment>> replies;
  final Map<String, bool> expandedComments;
  final List<TripLocation> tripUpdates;
  final bool isLoadingComments;
  final bool isLoadingMoreComments;
  final bool hasMoreComments;
  final bool isLoadingUpdates;
  final bool isLoadingMoreUpdates;
  final bool hasMoreUpdates;
  final bool isLoggedIn;
  final bool isAddingComment;
  final bool isTimelineCollapsed;
  final bool isCommentsCollapsed;
  final bool isTripInfoCollapsed;
  final bool isTripUpdateCollapsed;
  final bool isTripSettingsCollapsed;
  final bool isSendingUpdate;
  final CommentSortOption sortOption;
  final TextEditingController commentController;
  final ScrollController scrollController;
  final String? replyingToCommentId;
  final String? currentUserId;
  final bool isChangingStatus;
  final bool isChangingSettings;
  final bool
      showTripUpdatePanel; // Only show on Android for owner when trip is in progress
  final bool isFollowingTripOwner; // Track if following trip owner
  final bool hasSentFriendRequest; // Track if friend request sent
  final bool isAlreadyFriends; // Track if already friends with trip owner
  final bool isPromoted; // Track if trip is promoted
  final String? donationLink; // Donation link for promoted trips
  final List<UserAchievement> tripAchievements; // Achievements earned on trip

  // Callbacks
  final VoidCallback onToggleTripInfo;
  final VoidCallback onToggleComments;
  final VoidCallback onToggleTimeline;
  final VoidCallback onToggleTripUpdate;
  final VoidCallback onToggleTripSettings;
  final VoidCallback onRefreshTimeline;
  final VoidCallback? onLoadMoreUpdates;
  final Function(TripLocation)? onTimelineUpdateTap;
  final Function(CommentSortOption) onSortChanged;
  final Function(String) onReact;
  final Function(String, ReactionType) onReactionChipTap;
  final Function(String) onReply;
  final Function(String, bool) onToggleReplies;
  final VoidCallback onSendComment;
  final VoidCallback onCancelReply;
  final VoidCallback? onLoadMoreComments;
  final Function(TripStatus)? onStatusChange;
  final Function(bool automaticUpdates, int? updateRefresh,
      TripModality? tripModality)? onSettingsChange;
  final Future<void> Function(String? message) onSendTripUpdate;
  final VoidCallback? onFollowTripOwner;
  final VoidCallback? onSendFriendRequestToTripOwner;
  final VoidCallback? onTestBackgroundUpdate;
  final Function(Visibility)? onVisibilityChange;
  final bool showPlannedWaypoints; // Toggle for planned waypoints overlay
  final VoidCallback?
      onTogglePlannedWaypoints; // Callback to toggle planned waypoints
  final VoidCallback? onDeleteTrip; // Callback to delete the trip

  const TripDetailLayoutData({
    required this.trip,
    required this.comments,
    required this.replies,
    required this.expandedComments,
    required this.tripUpdates,
    required this.isLoadingComments,
    this.isLoadingMoreComments = false,
    this.hasMoreComments = false,
    required this.isLoadingUpdates,
    this.isLoadingMoreUpdates = false,
    this.hasMoreUpdates = false,
    required this.isLoggedIn,
    required this.isAddingComment,
    required this.isTimelineCollapsed,
    required this.isCommentsCollapsed,
    required this.isTripInfoCollapsed,
    required this.isTripUpdateCollapsed,
    required this.isTripSettingsCollapsed,
    required this.isSendingUpdate,
    required this.sortOption,
    required this.commentController,
    required this.scrollController,
    this.replyingToCommentId,
    this.currentUserId,
    this.isChangingStatus = false,
    this.isChangingSettings = false,
    this.showTripUpdatePanel = false,
    this.isFollowingTripOwner = false,
    this.hasSentFriendRequest = false,
    this.isAlreadyFriends = false,
    this.isPromoted = false,
    this.donationLink,
    this.tripAchievements = const [],
    this.showPlannedWaypoints = false,
    this.onTogglePlannedWaypoints,
    required this.onToggleTripInfo,
    required this.onToggleComments,
    required this.onToggleTimeline,
    required this.onToggleTripUpdate,
    required this.onToggleTripSettings,
    required this.onRefreshTimeline,
    this.onLoadMoreUpdates,
    this.onTimelineUpdateTap,
    required this.onSortChanged,
    required this.onReact,
    required this.onReactionChipTap,
    required this.onReply,
    required this.onToggleReplies,
    required this.onSendComment,
    required this.onCancelReply,
    this.onLoadMoreComments,
    this.onStatusChange,
    this.onSettingsChange,
    required this.onSendTripUpdate,
    this.onFollowTripOwner,
    this.onSendFriendRequestToTripOwner,
    this.onTestBackgroundUpdate,
    this.onVisibilityChange,
    this.onDeleteTrip,
  });
}

/// Abstract strategy for trip detail screen layouts
/// Implementations handle platform-specific layout logic
abstract class TripDetailLayoutStrategy {
  /// Calculate the width of the left panel (trip info + comments)
  double calculateLeftPanelWidth(
      BoxConstraints constraints, TripDetailLayoutData data);

  /// Build the left panel containing trip info and comments
  Widget buildLeftPanel(BoxConstraints constraints, TripDetailLayoutData data);

  /// Build the timeline panel (right side)
  Widget buildTimelinePanel(
      BoxConstraints constraints, TripDetailLayoutData data);

  /// Whether the left panel should stretch to bottom
  bool shouldLeftPanelStretchToBottom(TripDetailLayoutData data);

  /// Whether the timeline panel should stretch to bottom
  bool shouldTimelinePanelStretchToBottom(TripDetailLayoutData data);

  /// Helper to create TripInfoCard with proper callbacks
  @protected
  TripInfoCard createTripInfoCard(TripDetailLayoutData data) {
    return TripInfoCard(
      trip: data.trip,
      isCollapsed: data.isTripInfoCollapsed,
      onToggleCollapse: data.onToggleTripInfo,
      currentUserId: data.currentUserId,
      onFollowUser: data.onFollowTripOwner,
      onSendFriendRequest: data.onSendFriendRequestToTripOwner,
      isFollowing: data.isFollowingTripOwner,
      hasSentFriendRequest: data.hasSentFriendRequest,
      isAlreadyFriends: data.isAlreadyFriends,
      isPromoted: data.isPromoted,
      tripAchievements: data.tripAchievements,
      onVisibilityChange: data.onVisibilityChange,
    );
  }

  /// Helper to create TripSettingsPanel with proper callbacks
  @protected
  TripSettingsPanel createTripSettingsPanel(TripDetailLayoutData data) {
    return TripSettingsPanel(
      isCollapsed: data.isTripSettingsCollapsed,
      onToggleCollapse: data.onToggleTripSettings,
      isOwner:
          data.currentUserId != null && data.trip.userId == data.currentUserId,
      tripHasPlannedRoute: data.trip.hasPlannedRoute,
      showPlannedWaypoints: data.showPlannedWaypoints,
      onTogglePlannedWaypoints: data.onTogglePlannedWaypoints,
      automaticUpdates: data.trip.automaticUpdates,
      updateRefresh: data.trip.updateRefresh,
      tripModality: data.trip.tripModality,
      isLoading: data.isChangingSettings,
      onSettingsChange: data.onSettingsChange,
      tripStatus: data.trip.status,
      tripId: data.trip.id,
      onTestBackgroundUpdate: data.onTestBackgroundUpdate,
      onDeleteTrip: data.onDeleteTrip,
    );
  }

  /// Helper to create CommentsSection with proper callbacks
  @protected
  CommentsSection createCommentsSection(TripDetailLayoutData data) {
    return CommentsSection(
      comments: data.comments,
      replies: data.replies,
      expandedComments: data.expandedComments,
      tripUserId: data.trip.userId,
      isLoading: data.isLoadingComments,
      isLoadingMore: data.isLoadingMoreComments,
      hasMore: data.hasMoreComments,
      isLoggedIn: data.isLoggedIn,
      isAddingComment: data.isAddingComment,
      isCollapsed: data.isCommentsCollapsed,
      sortOption: data.sortOption,
      commentController: data.commentController,
      scrollController: data.scrollController,
      replyingToCommentId: data.replyingToCommentId,
      currentUserId: data.currentUserId,
      onToggleCollapse: data.onToggleComments,
      onSortChanged: data.onSortChanged,
      onReact: data.onReact,
      onReactionChipTap: data.onReactionChipTap,
      onReply: data.onReply,
      onToggleReplies: data.onToggleReplies,
      onSendComment: data.onSendComment,
      onCancelReply: data.onCancelReply,
      onLoadMore: data.onLoadMoreComments,
    );
  }

  /// Helper to create TimelinePanel with proper callbacks
  @protected
  TimelinePanel createTimelinePanel(TripDetailLayoutData data) {
    return TimelinePanel(
      updates: data.tripUpdates,
      isLoading: data.isLoadingUpdates,
      isLoadingMore: data.isLoadingMoreUpdates,
      hasMore: data.hasMoreUpdates,
      isCollapsed: data.isTimelineCollapsed,
      onToggleCollapse: data.onToggleTimeline,
      onRefresh: data.onRefreshTimeline,
      onLoadMore: data.onLoadMoreUpdates,
      onUpdateTap: data.onTimelineUpdateTap,
    );
  }

  /// Helper to create TripUpdatePanel with proper callbacks
  @protected
  TripUpdatePanel createTripUpdatePanel(TripDetailLayoutData data) {
    return TripUpdatePanel(
      isCollapsed: data.isTripUpdateCollapsed,
      isLoading: data.isSendingUpdate,
      onToggleCollapse: data.onToggleTripUpdate,
      onSendUpdate: data.onSendTripUpdate,
    );
  }
}

/// Factory to get the appropriate layout strategy based on screen size
class TripDetailLayoutStrategyFactory {
  static const double mobileBreakpoint = 600.0;

  static TripDetailLayoutStrategy getStrategy(double screenWidth) {
    if (screenWidth < mobileBreakpoint) {
      return MobileLayoutStrategy();
    }
    return DesktopLayoutStrategy();
  }

  static bool isMobile(double screenWidth) {
    return screenWidth < mobileBreakpoint;
  }
}
