import 'package:flutter_dotenv/flutter_dotenv.dart';

// Falls back to the live URL so the app still works if .env fails to load in
// a release build, instead of every request becoming "null/auth/login".
var host = dotenv.env['HOST'] ?? 'https://dummyjson.com';
const int demoUserId = 1;
const List<Map<String, String>> demoAccounts = [
  {'username': 'emilys', 'password': 'emilyspass'},
  {'username': 'michaelw', 'password': 'michaelwpass'},
  {'username': 'sophiab', 'password': 'sophiabpass'},
];

// Firestore collection names kept here so UserService and ChatService can
// never disagree on where the profiles are stored.
const String usersCollection = 'users';
const String chatRoomsCollection = 'chat_rooms';
