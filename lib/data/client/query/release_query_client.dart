import '../../../core/constants/api_endpoints.dart';
import '../../models/domain/release_note.dart';
import '../api_client.dart';

/// Release notes reads (Query service, port 8082).
class ReleaseQueryClient {
  final ApiClient _apiClient;

  ReleaseQueryClient({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: ApiEndpoints.queryBaseUrl);

  /// GET /releases?platform= → visible releases, newest first. Public.
  Future<List<ReleaseNote>> getReleases(String platform,
      {int size = 50}) async {
    final response = await _apiClient
        .get('${ApiEndpoints.releases}?platform=$platform&page=0&size=$size');
    return _apiClient
        .handlePageResponse(response, ReleaseNote.fromJson)
        .content;
  }

  /// GET /releases/me/unread → (lastSeenVersion, popup releases newest first).
  Future<({String? lastSeenVersion, List<ReleaseNote> releases})> getUnread(
      String platform, String currentVersion) async {
    final response = await _apiClient.get(
      '${ApiEndpoints.releasesUnread}?platform=$platform'
      '&currentVersion=${Uri.encodeQueryComponent(currentVersion)}',
      requireAuth: true,
    );
    return _apiClient.handleResponse(
        response,
        (j) => (
              lastSeenVersion: j['lastSeenVersion'] as String?,
              releases: [
                for (final r in j['releases'] as List? ?? const [])
                  ReleaseNote.fromJson(r as Map<String, dynamic>)
              ],
            ));
  }

  /// GET /admin/releases → drafts and published, newest first. ADMIN only.
  Future<List<ReleaseNote>> getAdminReleases({int size = 50}) async {
    final response = await _apiClient.get(
        '${ApiEndpoints.adminReleases}?page=0&size=$size',
        requireAuth: true);
    return _apiClient
        .handlePageResponse(response, ReleaseNote.fromJson)
        .content;
  }
}
