/// Request model for updating user profile
class UpdateProfileRequest {
  final String? displayName;
  final String? bio;

  UpdateProfileRequest({this.displayName, this.bio});

  Map<String, dynamic> toJson() => {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
      };
}
