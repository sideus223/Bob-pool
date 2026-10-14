class UserModel {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final int postCount;
  final int likeCount;
  final int followerCount;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.postCount = 0,
    this.likeCount = 0,
    this.followerCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'postCount': postCount,
      'likeCount': likeCount,
      'followerCount': followerCount,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      postCount: map['postCount'] ?? 0,
      likeCount: map['likeCount'] ?? 0,
      followerCount: map['followerCount'] ?? 0,
    );
  }
}
