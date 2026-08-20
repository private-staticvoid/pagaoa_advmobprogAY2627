import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/cart.dart'; // NEW — keeps LocalCartStore in sync with the session
import '../models/user.dart';

/// Keys used in SharedPreferences. Centralised here so there's exactly
/// one place that can typo a storage key.
class _Keys {
  static const id = 'id';
  static const username = 'username';
  static const email = 'email';
  static const firstName = 'firstName';
  static const lastName = 'lastName';
  static const gender = 'gender';
  static const image = 'image';
  static const accessToken = 'accessToken';
  static const refreshToken = 'refreshToken';
  static const isLoggedIn = 'isLoggedIn';
}

class UserService {
  /// LOGIN — POST /auth/login
  /// Enhancement 2: this is the auth call the sign-in screen invokes.
  /// On success the full user + token payload is persisted immediately
  /// (see saveUserData) so the splash screen can find it on next launch.
  Future<Map<String, dynamic>> loginUser(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$host/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'expiresInMins': 60,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      await saveUserData(decoded);
      // Enhancement 3: kick off the cart-by-userId fetch immediately on
      // login rather than waiting for the Cart tab to be opened, so it's
      // ready by the time the user gets there. loadInitial() resolves
      // the id itself (see models/cart.dart), so no argument is needed.
      unawaited(LocalCartStore.instance.loadInitial());
      return decoded;
    } else {
      // DummyJSON returns {"message": "..."} on failure.
      throw Exception(decoded['message']?.toString() ?? 'Login failed');
    }
  }

  /// SIGN UP — POST /users/add
  /// Enhancement 2: backs the new sign-up screen you asked for.
  /// IMPORTANT (DummyJSON limitation, not a bug in this code): /users/add
  /// is a *simulated* create — it responds with a realistic-looking new
  /// user object (including a fresh incremented id) but never actually
  /// persists it server-side, and it issues no access/refresh token. So a
  /// freshly "registered" account can never be used to log in afterwards.
  /// We surface that clearly in the UI (see signup_screen.dart) rather
  /// than silently pretending the account is real.
  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    String gender = 'male',
  }) async {
    final response = await http.post(
      Uri.parse('$host/users/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'email': email,
        'password': password,
        'gender': gender,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    } else {
      throw Exception(decoded['message']?.toString() ?? 'Sign up failed');
    }
  }

  /// SAVE USER DATA -> SharedPreferences
  /// Enhancement 3: routed through the User model (User.fromJson) so
  /// every field written here is type-checked against the model instead
  /// of being pulled ad-hoc out of a raw map.
  /// Enhancement 1: also flips an explicit `isLoggedIn` flag, which is
  /// the single source of truth the splash screen checks.
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final user = User.fromJson(userData);

    await prefs.setInt(_Keys.id, user.id);
    await prefs.setString(_Keys.username, user.username);
    await prefs.setString(_Keys.email, user.email);
    await prefs.setString(_Keys.firstName, user.firstName);
    await prefs.setString(_Keys.lastName, user.lastName);
    await prefs.setString(_Keys.gender, user.gender);
    await prefs.setString(_Keys.image, user.image);
    await prefs.setString(_Keys.accessToken, user.accessToken);
    await prefs.setString(_Keys.refreshToken, user.refreshToken);
    await prefs.setBool(_Keys.isLoggedIn, user.accessToken.isNotEmpty);
  }

  /// Retrieve the raw map (kept for backwards compatibility with any
  /// screen that still expects the flat Map<String, dynamic> shape).
  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      _Keys.id: prefs.getInt(_Keys.id) ?? 0,
      _Keys.username: prefs.getString(_Keys.username) ?? '',
      _Keys.email: prefs.getString(_Keys.email) ?? '',
      _Keys.firstName: prefs.getString(_Keys.firstName) ?? '',
      _Keys.lastName: prefs.getString(_Keys.lastName) ?? '',
      _Keys.gender: prefs.getString(_Keys.gender) ?? '',
      _Keys.image: prefs.getString(_Keys.image) ?? '',
      _Keys.accessToken: prefs.getString(_Keys.accessToken) ?? '',
      _Keys.refreshToken: prefs.getString(_Keys.refreshToken) ?? '',
    };
  }

  /// Enhancement 3: typed accessor — this is what ProfileScreen and
  /// CartScreen actually use, so they get a proper `User` object instead
  /// of a Map they'd have to re-parse.
  Future<User> getUser() async {
    final userData = await getUserData();
    return User.fromJson(userData);
  }

  /// -------------------------------------------------------------
  /// PERSISTENT AUTH CHECK
  /// -------------------------------------------------------------
  /// Enhancement 1: this is the method splash_screen.dart calls. A user
  /// is considered "still logged in" if we previously stored a non-empty
  /// access token for them — no network round trip needed, so the splash
  /// check is fast and works fully offline.
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_Keys.accessToken) ?? '';
    final flag = prefs.getBool(_Keys.isLoggedIn) ?? false;
    return flag && token.isNotEmpty;
  }

  /// -------------------------------------------------------------
  /// LOGOUT
  /// -------------------------------------------------------------
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      // Enhancement 3: clear the cached cart too — otherwise the next
      // person to log in on this device would see the previous user's
      // cart for a moment before their own loads.
      LocalCartStore.instance.reset();
    } catch (e) {
      throw Exception('Failed to log out: $e');
    }
  }
}
