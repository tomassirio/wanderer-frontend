import 'package:flutter_test/flutter_test.dart';
import 'package:wanderer_frontend/data/models/auth_models.dart';

void main() {
  group('AuthModels', () {
    group('RegisterRequest', () {
      test('toJson converts RegisterRequest correctly', () {
        final request = RegisterRequest(
          email: 'test@example.com',
          password: 'password123',
          username: 'testuser',
        );

        final json = request.toJson();

        expect(json['email'], 'test@example.com');
        expect(json['password'], 'password123');
        expect(json['username'], 'testuser');
      });

      test('toJson excludes null displayName', () {
        final request = RegisterRequest(
          email: 'test@example.com',
          password: 'password123',
          username: 'testuser',
        );

        final json = request.toJson();

        expect(json.containsKey('displayName'), false);
      });
    });

    group('LoginRequest', () {
      test('toJson converts LoginRequest correctly', () {
        final request =
            LoginRequest(identifier: 'test', password: 'password123');

        final json = request.toJson();

        expect(json['identifier'], 'test');
        expect(json['password'], 'password123');
      });
    });

    // group('AuthResponse', () {
    //   test('fromJson creates AuthResponse from JSON', () {
    //     final json = {
    //       'accessToken': 'access123',
    //       'refreshToken': 'refresh456',
    //       'userId': 'user789',
    //       'email': 'test@example.com',
    //       'username': 'testuser',
    //     };
    //
    //     final response = AuthResponse.fromJson(json);
    //
    //     expect(response.accessToken, 'access123');
    //     expect(response.refreshToken, 'refresh456');
    //     expect(response.userId, 'user789');
    //     expect(response.email, 'test@example.com');
    //     expect(response.username, 'testuser');
    //   });

    //   test('toJson converts AuthResponse correctly', () {
    //     final response = AuthResponse(
    //       accessToken: 'access123',
    //       refreshToken: 'refresh456',
    //       userId: 'user789',
    //       email: 'test@example.com',
    //       username: 'testuser',
    //     );
    //
    //     final json = response.toJson();
    //
    //     expect(json['accessToken'], 'access123');
    //     expect(json['refreshToken'], 'refresh456');
    //     expect(json['userId'], 'user789');
    //     expect(json['email'], 'test@example.com');
    //     expect(json['username'], 'testuser');
    //   });
    // });

    // group('PasswordChangeRequest', () {
    //   test('toJson converts PasswordChangeRequest correctly', () {
    //     final request = PasswordChangeRequest(
    //       currentPassword: 'old123',
    //       newPassword: 'new456',
    //     );
    //
    //     final json = request.toJson();
    //
    //     expect(json['currentPassword'], 'old123');
    //     expect(json['newPassword'], 'new456');
    //   });
    // });
  });
}
