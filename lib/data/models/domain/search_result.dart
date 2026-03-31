/// User search result model
class UserSearchResult {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  UserSearchResult({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
      };
}

/// Trip summary model for search results (lightweight)
class TripSummary {
  final String id;
  final String name;
  final String userId;
  final String username;
  final String visibility;
  final String status;
  final String? tripModality;
  final DateTime createdAt;
  final int commentsCount;
  final int? currentDay;
  final String? tripPlanId;
  final bool isPromoted;
  final DateTime? promotedAt;
  final bool isPreAnnounced;
  final DateTime? countdownStartDate;
  final String thumbnailUrl;

  TripSummary({
    required this.id,
    required this.name,
    required this.userId,
    required this.username,
    required this.visibility,
    required this.status,
    this.tripModality,
    required this.createdAt,
    required this.commentsCount,
    this.currentDay,
    this.tripPlanId,
    required this.isPromoted,
    this.promotedAt,
    required this.isPreAnnounced,
    this.countdownStartDate,
    required this.thumbnailUrl,
  });

  factory TripSummary.fromJson(Map<String, dynamic> json) {
    final tripSettings = json['tripSettings'] as Map<String, dynamic>?;

    return TripSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      visibility: tripSettings?['visibility'] as String? ?? 'PUBLIC',
      status: tripSettings?['tripStatus'] as String? ?? 'IN_PROGRESS',
      tripModality: tripSettings?['tripModality'] as String?,
      createdAt:
          DateTime.tryParse(json['creationTimestamp'] as String? ?? '') ??
              DateTime.now(),
      commentsCount: json['commentsCount'] as int? ?? 0,
      currentDay: json['currentDay'] as int?,
      tripPlanId: json['tripPlanId'] as String?,
      isPromoted: json['isPromoted'] as bool? ?? false,
      promotedAt: json['promotedAt'] != null
          ? DateTime.tryParse(json['promotedAt'] as String)
          : null,
      isPreAnnounced: json['isPreAnnounced'] as bool? ?? false,
      countdownStartDate: json['countdownStartDate'] != null
          ? DateTime.tryParse(json['countdownStartDate'] as String)
          : null,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    );
  }

  /// Generate user profile picture URL based on user ID
  String get userProfilePictureUrl => '/thumbnails/profiles/$userId.png';
}

/// Paginated search results response
class SearchResultsResponse {
  final PageResponse<UserSearchResult> users;
  final PageResponse<TripSummary> trips;

  SearchResultsResponse({
    required this.users,
    required this.trips,
  });

  factory SearchResultsResponse.fromJson(Map<String, dynamic> json) {
    return SearchResultsResponse(
      users: PageResponse<UserSearchResult>.fromJson(
        json['users'] as Map<String, dynamic>? ?? {},
        (item) => UserSearchResult.fromJson(item as Map<String, dynamic>),
      ),
      trips: PageResponse<TripSummary>.fromJson(
        json['trips'] as Map<String, dynamic>? ?? {},
        (item) => TripSummary.fromJson(item as Map<String, dynamic>),
      ),
    );
  }

  bool get isEmpty => users.content.isEmpty && trips.content.isEmpty;
}

/// Generic page response for paginated data
class PageResponse<T> {
  final List<T> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;
  final bool first;
  final bool last;
  final bool empty;
  final int numberOfElements;

  PageResponse({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
    required this.first,
    required this.last,
    required this.empty,
    required this.numberOfElements,
  });

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) itemParser,
  ) {
    final contentList = json['content'] as List<dynamic>? ?? [];
    return PageResponse<T>(
      content: contentList.map((item) => itemParser(item)).toList(),
      totalElements: json['totalElements'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      number: json['number'] as int? ?? 0,
      size: json['size'] as int? ?? 10,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
      empty: json['empty'] as bool? ?? true,
      numberOfElements: json['numberOfElements'] as int? ?? 0,
    );
  }

  bool get hasNext => !last;
  bool get hasPrevious => !first;
}
