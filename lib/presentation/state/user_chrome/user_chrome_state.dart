/// Identity/auth-chrome state shown in every screen's `WandererAppBar` and
/// `AppSidebar` (username/avatar/login-status/admin-flag). Shared across
/// every screen that shows the app bar or sidebar — unlike per-trip
/// notifiers, this is app-global, not scoped to one screen visit.
class UserChromeState {
  final String? username;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;
  final bool isLoggedIn;
  final bool isAdmin;

  const UserChromeState({
    this.username,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.isLoggedIn = false,
    this.isAdmin = false,
  });

  UserChromeState copyWith({
    String? username,
    String? userId,
    String? displayName,
    String? avatarUrl,
    bool? isLoggedIn,
    bool? isAdmin,
  }) {
    return UserChromeState(
      username: username ?? this.username,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
