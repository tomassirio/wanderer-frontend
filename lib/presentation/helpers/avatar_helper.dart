/// Helper functions for avatar display logic
class AvatarHelper {
  /// Generate initials from display name (max 3 letters)
  /// Examples: "John" -> "J", "John Doe" -> "JD", "John Paul Jones" -> "JPJ"
  static String getInitials(String? displayName, String username) {
    final name = displayName?.trim() ?? username.trim();
    if (name.isEmpty) return username.substring(0, 1).toUpperCase();
    
    final words = name.split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    }
    
    // Take first letter of up to 3 words
    return words
        .take(3)
        .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
        .where((char) => char.isNotEmpty)
        .join();
  }
}
