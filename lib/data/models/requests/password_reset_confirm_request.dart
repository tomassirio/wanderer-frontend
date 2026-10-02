class PasswordResetConfirmRequest {
  final String token;
  final String newPassword;

  const PasswordResetConfirmRequest(
      {required this.token, required this.newPassword});

  Map<String, dynamic> toJson() => {'token': token, 'newPassword': newPassword};
}
