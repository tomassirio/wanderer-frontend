import 'dart:convert';
import '../client/api_client.dart';
import '../models/domain/search_result.dart';
import '../../core/constants/api_endpoints.dart';

/// Service for search operations
class SearchService {
  final ApiClient _queryClient;

  SearchService({ApiClient? queryClient})
      : _queryClient =
            queryClient ?? ApiClient(baseUrl: ApiEndpoints.queryBaseUrl);

  /// Search for users and trips with independent pagination
  ///
  /// [query] - Search term to match against usernames, display names, trip names, and trip owner usernames
  /// [userPage] - Page number for user results (0-based)
  /// [userSize] - Page size for user results
  /// [tripPage] - Page number for trip results (0-based)
  /// [tripSize] - Page size for trip results
  Future<SearchResultsResponse> search(
    String query, {
    int userPage = 0,
    int userSize = 10,
    int tripPage = 0,
    int tripSize = 10,
  }) async {
    if (query.trim().isEmpty) {
      return SearchResultsResponse(
        users: PageResponse(
          content: [],
          totalElements: 0,
          totalPages: 0,
          number: 0,
          size: userSize,
          first: true,
          last: true,
          empty: true,
          numberOfElements: 0,
        ),
        trips: PageResponse(
          content: [],
          totalElements: 0,
          totalPages: 0,
          number: 0,
          size: tripSize,
          first: true,
          last: true,
          empty: true,
          numberOfElements: 0,
        ),
      );
    }

    final queryParams = {
      'q': Uri.encodeComponent(query),
      'userPage': userPage.toString(),
      'userSize': userSize.toString(),
      'tripPage': tripPage.toString(),
      'tripSize': tripSize.toString(),
    };

    final queryString =
        queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');

    final response = await _queryClient.get(
      '${ApiEndpoints.search}?$queryString',
      requireAuth: false,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return SearchResultsResponse.fromJson(data);
    } else {
      throw Exception('Failed to search: ${response.statusCode}');
    }
  }
}
