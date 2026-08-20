// models/user.dart
//
// ============================================================
// ENHANCEMENT 3 — User model
// ------------------------------------------------------------
// You said you didn't have a `user.dart` model yet — this is it.
// It mirrors exactly what DummyJSON's `POST /auth/login` returns, so
// `User.fromJson(loginResponseBody)` works directly with no mapping
// glue code. UserService uses this model to type-check every field it
// writes into / reads out of SharedPreferences (see user_service.dart),
// and ProfileScreen renders straight from a `User` instance.
// ============================================================

class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String image;
  final String accessToken;
  final String refreshToken;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.image,
    required this.accessToken,
    required this.refreshToken,
  });

  /// Convenience getter used throughout the UI (e.g. ProfileScreen header).
  String get fullName => '$firstName $lastName'.trim();

  /// An "empty" user — handy as a default/placeholder before real data
  /// has loaded, so widgets don't need null-checks everywhere.
  factory User.empty() => const User(
    id: 0,
    username: '',
    email: '',
    firstName: '',
    lastName: '',
    gender: '',
    image: '',
    accessToken: '',
    refreshToken: '',
  );

  bool get isEmpty => id == 0 && username.isEmpty;

  /// Builds a [User] from a DummyJSON auth response, or from the flat
  /// map UserService.getUserData() returns when reading SharedPreferences
  /// back out. Handles both `accessToken` (current DummyJSON field name)
  /// and the older `token` field name defensively, since API docs and
  /// live responses have used both over time.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? 0}') ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      accessToken:
          json['accessToken']?.toString() ?? json['token']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    'image': image,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? gender,
    String? image,
    String? accessToken,
    String? refreshToken,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      image: image ?? this.image,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}
