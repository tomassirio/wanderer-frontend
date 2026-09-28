/// Request model for exchanging an SSO authorization code for tokens
class SsoExchangeRequest {
  final String code;
  final String codeVerifier;

  SsoExchangeRequest({required this.code, required this.codeVerifier});

  Map<String, dynamic> toJson() => {
        'code': code,
        'codeVerifier': codeVerifier,
      };
}
