import '../models/comment_models.dart';
import '../models/responses/page_response.dart';
import '../client/clients.dart';

/// Service for comment operations
class CommentService {
  final CommentQueryClient _commentQueryClient;
  final CommentCommandClient _commentCommandClient;

  CommentService({
    CommentQueryClient? commentQueryClient,
    CommentCommandClient? commentCommandClient,
  })  : _commentQueryClient = commentQueryClient ?? CommentQueryClient(),
        _commentCommandClient = commentCommandClient ?? CommentCommandClient();

  // ===== Comment Query Operations =====

  /// Get all comments for a trip (paginated, includes nested replies)
  Future<PageResponse<Comment>> getCommentsByTripId(
    String tripId, {
    int page = 0,
    int size = 100,
  }) async {
    return await _commentQueryClient.getTripComments(tripId,
        page: page, size: size);
  }

  /// Get replies for a specific comment
  /// Since the API returns comments with nested replies, we filter them from the parent comment
  Future<List<Comment>> getRepliesByCommentId(String commentId) async {
    final comment = await _commentQueryClient.getCommentById(commentId);
    return comment.replies ?? [];
  }

  /// Get comment by ID
  Future<Comment> getCommentById(String commentId) async {
    return await _commentQueryClient.getCommentById(commentId);
  }

  // ===== Comment Command Operations =====

  /// Add a new comment (top-level or reply)
  /// Returns the comment ID immediately. Full data will be delivered via WebSocket.
  Future<String> addComment(
    String tripId,
    CreateCommentRequest request,
  ) async {
    return await _commentCommandClient.createComment(tripId, request);
  }

  /// Add a reaction to a comment
  /// Returns the comment ID immediately. Full data will be delivered via WebSocket.
  Future<String> addReaction(
      String commentId, AddReactionRequest request) async {
    return await _commentCommandClient.addReaction(commentId, request);
  }

  /// Remove a reaction from a comment
  /// Returns the comment ID immediately. Full data will be delivered via WebSocket.
  Future<String> removeReaction(
      String commentId, AddReactionRequest request) async {
    return await _commentCommandClient.removeReaction(commentId, request);
  }
}
