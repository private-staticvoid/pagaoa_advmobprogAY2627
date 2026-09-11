// UserService — the ONE place in the app that knows how to log in, sign up,
// log out and manage accounts. Screens never call http / FirebaseAuth /
// Firestore / SharedPreferences directly; they only call methods here.
//
// Lab 4: DummyJSON login + SharedPreferences session (kept, still works).
// Lab 5: Firebase Authentication + Cloud Firestore profile, and a LoginType
//        so the rest of the app knows which backend the session came from.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
// `as fb` because firebase_auth also has a class called `User`, which would
// clash with OUR `User` model in models/user.dart. So Firebase's user is
// written `fb.User` in this file.
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/cart.dart';
import '../models/login_type.dart';
import '../models/user.dart';

/// globally reachable UserService. Screens in this
/// project create `UserService()` directly, which works the same way since
/// the class keeps no private state of its own.
ValueNotifier<UserService> userService = ValueNotifier(UserService());

/// SharedPreferences keys, kept in one place so nothing can typo a key.
class _Keys {
  static const id = 'id';
  static const uid = 'uid';
  static const username = 'username';
  static const email = 'email';
  static const firstName = 'firstName';
  static const lastName = 'lastName';
  static const gender = 'gender';
  static const image = 'image';
  static const age = 'age';
  static const phone = 'phone';
  static const accessToken = 'accessToken';
  static const refreshToken = 'refreshToken';
  static const isLoggedIn = 'isLoggedIn';
  static const loginType = 'loginType';
}

class UserService {
  static const _timeout = Duration(seconds: 8);

  //  FIREBASE AUTH  (the code snippet from the lab handout)

  final fb.FirebaseAuth firebaseAuth = fb.FirebaseAuth.instance;

  fb.User? get currentUser => firebaseAuth.currentUser;

  Stream<fb.User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<fb.UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<fb.UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  Future<void> updateUsername({required String username}) async {
    final user = _requireFirebaseUser();
    await user.updateDisplayName(username);

    // Lab 5 extra: keep Firestore + the local session in sync so the new
    // username shows up everywhere right away.
    await _writeProfileDoc(user.uid, {'username': username});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_Keys.username, username);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    final user = _requireFirebaseUser();
    final credential = fb.EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    // Firebase only lets you delete an account if you logged in recently,
    // so we re-check the password first.
    await user.reauthenticateWithCredential(credential);

    // Delete the Firestore profile BEFORE the auth account, because the
    // security rules only allow a signed-in user to delete their own doc.
    await _deleteProfileDoc(user.uid);
    await user.delete();
    await logout(); // signs out + clears SharedPreferences + resets cart
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async {
    final user = _requireFirebaseUser();
    final credential = fb.EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  //  FIREBASE — what the screens actually call
  //  (wraps signIn/createAccount above + saves the session + profile)

  /// Sign in screen (Firebase mode).
  Future<User> loginWithFirebase({
    required String email,
    required String password,
  }) async {
    final credential = await signIn(email: email, password: password);
    final fbUser = credential.user!;
    final profile = await _readProfileDoc(fbUser.uid);
    return _saveFirebaseSession(fbUser, profile: profile);
  }

  /// Sign up screen (Firebase mode). Creates the Auth account, then stores
  /// the extra fields (name, age, contact no...) in Firestore, because
  /// Firebase Auth itself only stores email, password and display name.
  Future<User> registerWithFirebase({
    required String firstName,
    required String lastName,
    required int age,
    required String contactNo,
    required String username,
    required String email,
    required String password,
    required String gender,
  }) async {
    final credential = await createAccount(email: email, password: password);
    final fbUser = credential.user!;
    await fbUser.updateDisplayName(username);

    // Same field names as DummyJSON's /users so one User.fromJson reads both.
    final profile = <String, dynamic>{
      'uid': fbUser.uid,
      'firstName': firstName,
      'lastName': lastName,
      'age': age,
      'phone': contactNo,
      'username': username,
      'email': email,
      'gender': gender,
      'loginType': LoginType.firebase.name,
    };
    await _writeProfileDoc(fbUser.uid, {
      ...profile,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return _saveFirebaseSession(fbUser, profile: profile);
  }

  Future<User> _saveFirebaseSession(
    fb.User fbUser, {
    Map<String, dynamic>? profile,
  }) async {
    // The ID token is Firebase's equivalent of DummyJSON's accessToken.
    // The SDK refreshes it automatically (roughly every hour).
    final idToken = await fbUser.getIdToken() ?? '';
    final email = fbUser.email ?? '';

    final data = <String, dynamic>{
      ...?profile,
      'id': 0,
      'uid': fbUser.uid,
      'email': email,
      'username':
          profile?['username'] ?? fbUser.displayName ?? email.split('@').first,
      'image': fbUser.photoURL ?? '',
      'accessToken': idToken,
      'refreshToken': fbUser.refreshToken ?? '',
      'loginType': LoginType.firebase.name,
    };

    await saveUserData(data);
    unawaited(LocalCartStore.instance.loadInitial());
    return User.fromJson(data);
  }

  fb.User _requireFirebaseUser() {
    final user = currentUser;
    if (user == null) throw Exception('No Firebase user is signed in.');
    return user;
  }

  // ---------------- Firestore profile document: users/{uid} ----------------
  // Wrapped in try/catch + timeout so a Firestore problem (e.g. database
  // not created yet) never crashes login — it just logs to the console.

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      FirebaseFirestore.instance.collection('users');

  Future<Map<String, dynamic>?> _readProfileDoc(String uid) async {
    try {
      final snap = await _usersCollection.doc(uid).get().timeout(_timeout);
      return snap.data();
    } catch (e) {
      debugPrint('[UserService] Firestore read skipped: $e');
      return null;
    }
  }

  Future<void> _writeProfileDoc(String uid, Map<String, dynamic> data) async {
    try {
      await _usersCollection
          .doc(uid)
          .set(data, SetOptions(merge: true))
          .timeout(_timeout);
    } catch (e) {
      debugPrint('[UserService] Firestore write skipped: $e');
    }
  }

  Future<void> _deleteProfileDoc(String uid) async {
    try {
      await _usersCollection.doc(uid).delete().timeout(_timeout);
    } catch (e) {
      debugPrint('[UserService] Firestore delete skipped: $e');
    }
  }

  //  DUMMYJSON  (Lab 4 — unchanged behaviour, now also tagged with LoginType)

  /// POST /auth/login  (username + password of a DummyJSON demo user)
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

    if (response.statusCode != 200) {
      throw Exception(decoded['message']?.toString() ?? 'Login failed');
    }

    // /auth/login doesn't return age or phone, so we use the new token to
    // ask /auth/me for the full profile (this also proves the token works).
    final profile = await _fetchDummyJsonProfile(
      decoded['accessToken']?.toString() ?? '',
    );

    final data = <String, dynamic>{
      ...?profile,
      ...decoded,
      'loginType': LoginType.dummyJson.name,
    };
    await saveUserData(data);
    unawaited(LocalCartStore.instance.loadInitial());
    return data;
  }

  /// GET /auth/me  (Authorization: Bearer <accessToken>)
  Future<Map<String, dynamic>?> _fetchDummyJsonProfile(String token) async {
    if (token.isEmpty) return null;
    try {
      final res = await http
          .get(
            Uri.parse('$host/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[UserService] /auth/me skipped: $e');
    }
    return null;
  }

  /// POST /users/add — DummyJSON only SIMULATES this. It returns a new user
  /// object but never saves it, so that account can't log in afterwards.
  /// Kept for comparison with Firebase (see the discussion in README.md).
  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    String gender = 'male',
    int? age,
    String? phone,
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
        if (age != null) 'age': age,
        if (phone != null) 'phone': phone,
      }),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      return decoded;
    }
    throw Exception(decoded['message']?.toString() ?? 'Sign up failed');
  }

  //  SESSION  (shared by both backends)

  /// Saves the session to SharedPreferences (goes through User.fromJson so
  /// every value is type-checked by the model).
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final user = User.fromJson(userData);

    await prefs.setInt(_Keys.id, user.id);
    await prefs.setString(_Keys.uid, user.uid);
    await prefs.setString(_Keys.username, user.username);
    await prefs.setString(_Keys.email, user.email);
    await prefs.setString(_Keys.firstName, user.firstName);
    await prefs.setString(_Keys.lastName, user.lastName);
    await prefs.setString(_Keys.gender, user.gender);
    await prefs.setString(_Keys.image, user.image);
    await prefs.setInt(_Keys.age, user.age);
    await prefs.setString(_Keys.phone, user.phone);
    await prefs.setString(_Keys.accessToken, user.accessToken);
    await prefs.setString(_Keys.refreshToken, user.refreshToken);
    await prefs.setString(_Keys.loginType, user.loginType.name);
    await prefs.setBool(_Keys.isLoggedIn, user.accessToken.isNotEmpty);
  }

  /// Enhancement 3 of the handout: "Fetch user data via
  /// UserService().getUserData()". Returns the saved session as a map.
  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      _Keys.id: prefs.getInt(_Keys.id) ?? 0,
      _Keys.uid: prefs.getString(_Keys.uid) ?? '',
      _Keys.username: prefs.getString(_Keys.username) ?? '',
      _Keys.email: prefs.getString(_Keys.email) ?? '',
      _Keys.firstName: prefs.getString(_Keys.firstName) ?? '',
      _Keys.lastName: prefs.getString(_Keys.lastName) ?? '',
      _Keys.gender: prefs.getString(_Keys.gender) ?? '',
      _Keys.image: prefs.getString(_Keys.image) ?? '',
      _Keys.age: prefs.getInt(_Keys.age) ?? 0,
      _Keys.phone: prefs.getString(_Keys.phone) ?? '',
      _Keys.accessToken: prefs.getString(_Keys.accessToken) ?? '',
      _Keys.refreshToken: prefs.getString(_Keys.refreshToken) ?? '',
      _Keys.loginType: prefs.getString(_Keys.loginType) ?? '',
    };
  }

  /// Same data as getUserData(), but as a typed `User` object.
  Future<User> getUser() async => User.fromJson(await getUserData());

  Future<LoginType> getLoginType() async {
    final prefs = await SharedPreferences.getInstance();
    return LoginTypeX.fromName(prefs.getString(_Keys.loginType));
  }

  /// Splash screen check: is there still a valid session on this device?
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final flag = prefs.getBool(_Keys.isLoggedIn) ?? false;
    if (!flag) return false;

    if (await getLoginType() == LoginType.firebase) {
      // FirebaseAuth keeps its own session on the device. The first value
      // of authStateChanges() is the restored user (or null if none).
      final user = await firebaseAuth.authStateChanges().first;
      return user != null;
    }

    final token = prefs.getString(_Keys.accessToken) ?? '';
    return token.isNotEmpty;
  }

  /// TOKEN REFRESH — called by the splash screen after isLoggedIn().
  /// Returns false only when the backend says the session is really dead
  /// (e.g. account deleted/disabled in the Firebase Console). If we're just
  /// offline, it returns true so the app still opens, like in Lab 4.
  Future<bool> refreshSession() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (await getLoginType() == LoginType.firebase) {
        final user = currentUser;
        if (user == null) return false;
        await user.reload().timeout(_timeout); // fails if user was removed
        final token = await user.getIdToken(true).timeout(_timeout);
        await prefs.setString(_Keys.accessToken, token ?? '');
        return true;
      }

      // DummyJSON: POST /auth/refresh with the saved refreshToken.
      final refreshToken = prefs.getString(_Keys.refreshToken) ?? '';
      if (refreshToken.isEmpty) return true;
      final res = await http
          .post(
            Uri.parse('$host/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'refreshToken': refreshToken,
              'expiresInMins': 60,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        await prefs.setString(
          _Keys.accessToken,
          body['accessToken']?.toString() ?? '',
        );
        await prefs.setString(
          _Keys.refreshToken,
          body['refreshToken']?.toString() ?? refreshToken,
        );
        return true;
      }
      return res.statusCode != 401 && res.statusCode != 403;
    } on fb.FirebaseAuthException catch (e) {
      const deadSession = {
        'user-not-found',
        'user-disabled',
        'user-token-expired',
        'invalid-user-token',
      };
      return !deadSession.contains(e.code);
    } catch (e) {
      debugPrint('[UserService] refreshSession offline/timeout: $e');
      return true;
    }
  }

  /// LOGOUT — signs out of Firebase (if signed in), clears the saved
  /// session/token from SharedPreferences, and empties the cached cart.
  Future<void> logout() async {
    try {
      if (currentUser != null) await signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      LocalCartStore.instance.reset();
    } catch (e) {
      throw Exception('Failed to log out: $e');
    }
  }
}
