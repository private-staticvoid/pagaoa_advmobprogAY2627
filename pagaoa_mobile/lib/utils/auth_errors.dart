// LAB 5 — Friendly error messages
// FirebaseAuth throws FirebaseAuthException with a `code` like
// "invalid-credential". Users shouldn't see raw codes, so every screen
// passes caught errors through `friendlyAuthError()` before showing them.

import 'package:firebase_auth/firebase_auth.dart';

String friendlyAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a bit and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'requires-recent-login':
        return 'Please log out and log in again, then retry.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in the Firebase '
            'Console (Authentication → Sign-in method).';
      default:
        return error.message ?? 'Authentication error (${error.code}).';
    }
  }
  return error.toString().replaceFirst('Exception: ', '');
}
