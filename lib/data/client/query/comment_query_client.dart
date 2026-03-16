import '../../../core/constants/api_endpoints.dart';
import '../../models/comment_models.dart';
import '../../models/responses/page_response.dart';
import '../api_client.dart';

/// Comment query client for read operations (Port 8082)
class CommentQueryClient {
  final ApiClient _apiClient;

  CommentQueryClient({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: ApiEndpoints.queryBaseUrl);

  /// Get comment by ID
  /// Requires authentication (USER, ADMIN)
  Future<Comment> getCommentById(String commentId) async {
    final response = await _apiClient.get(
      '/comments/$commentId',
      requireAuth: true,
    );
    return _apiClient.handleResponse(response, Comment.fromJson);
  }

  /// Get all comments for a trip (paginated, includes top-level comments with replies)
  /// Requires authentication (USER, ADMIN)
  Future<PageResponse<Comment>> getTripComments(
    String tripId, {
    int page = 0,
    int size = 100,
    String sort = 'timestamp,desc',
  }) async {
    final endpoint =
        '${ApiEndpoints.tripComments(tripId)}?page=$page&size=$size&sort=$sort';
    final response = await _apiClient.get(
      endpoint,
      requireAuth: true,
    );
    return _apiClient.handlePageResponse(response, Comment.fromJson);
  }
}
