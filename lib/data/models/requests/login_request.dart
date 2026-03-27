/// Request model for user login
class LoginRequest {
  final String identifier;
  final String password;

  LoginRequest({required this.identifier, required this.password});

  Map<String, dynamic> toJson() =>
      {'identifier': identifier, 'password': password};
}
