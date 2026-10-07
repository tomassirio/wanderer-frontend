import '../../../core/constants/api_endpoints.dart';
import '../../models/domain/release_note.dart';
import '../api_client.dart';

/// Release notes writes (Command service, port 8081).
class ReleaseCommandClient {
  final ApiClient _apiClient;

  ReleaseCommandClient({ApiClient? apiClient})
      : _apiClient =
            apiClient ?? ApiClient(baseUrl: ApiEndpoints.commandBaseUrl);

  /// PUT /releases/me/seen. Monotonic on the server.
  Future<void> markSeen(String version) async {
    final response = await _apiClient.put(ApiEndpoints.releasesSeen,
        body: {'version': version}, requireAuth: true);
    _apiClient.handleNoContentResponse(response);
  }

  /// PUT /admin/releases/{version}: full replace of the editable fields.
  Future<ReleaseNote> update(ReleaseNote note) async {
    final response = await _apiClient.put(
        ApiEndpoints.adminRelease(note.version),
        body: note.toUpdateJson(),
        requireAuth: true);
    return _apiClient.handleResponse(response, ReleaseNote.fromJson);
  }

  /// POST /admin/releases/{version}/publish. Idempotent.
  Future<ReleaseNote> publish(String version) async {
    final response = await _apiClient.post(
        ApiEndpoints.adminReleasePublish(version),
        body: const {},
        requireAuth: true);
    return _apiClient.handleResponse(response, ReleaseNote.fromJson);
  }
}
