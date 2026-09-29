/// An SSO identity provider supported for login.
class SsoProvider {
  final String id;

  const SsoProvider._(this.id);

  static const google = SsoProvider._('google');
}
