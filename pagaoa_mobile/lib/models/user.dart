// User model (Lab 4, extended in Lab 5)
//
// ONE model for BOTH backends. DummyJSON and our Firestore profile document
// use the same field names (firstName, lastName, age, phone, ...), so a
// single `User.fromJson` can read either one.
//
// Lab 5 additions: age, phone (contactNo), uid (Firebase id), loginType.

import 'login_type.dart';

class User {
  final int id; // DummyJSON numeric id (0 for Firebase users)
  final String uid; // Firebase uid ('' for DummyJSON users)
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String image;
  final int age;
  final String phone; // shown as "Contact No." in the UI
  final String accessToken;
  final String refreshToken;
  final LoginType loginType;

  const User({
    required this.id,
    required this.uid,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.image,
    required this.age,
    required this.phone,
    required this.accessToken,
    required this.refreshToken,
    required this.loginType,
  });

  String get fullName => '$firstName $lastName'.trim();

  bool get isFirebase => loginType == LoginType.firebase;

  factory User.empty() => const User(
    id: 0,
    uid: '',
    username: '',
    email: '',
    firstName: '',
    lastName: '',
    gender: '',
    image: '',
    age: 0,
    phone: '',
    accessToken: '',
    refreshToken: '',
    loginType: LoginType.dummyJson,
  );

  bool get isEmpty => id == 0 && uid.isEmpty && username.isEmpty;

  /// Reads a DummyJSON response, a Firestore profile document, or the flat
  /// map that UserService.getUserData() builds from SharedPreferences.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _toInt(json['id']),
      uid: json['uid']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      age: _toInt(json['age']),
      // DummyJSON calls it "phone"; the lab handout calls it "contactNo".
      phone: (json['phone'] ?? json['contactNo'])?.toString() ?? '',
      accessToken:
          json['accessToken']?.toString() ?? json['token']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      loginType: LoginTypeX.fromName(json['loginType']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'username': username,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'gender': gender,
    'image': image,
    'age': age,
    'phone': phone,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'loginType': loginType.name,
  };

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }
}
