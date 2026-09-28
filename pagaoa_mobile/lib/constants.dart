import 'package:flutter_dotenv/flutter_dotenv.dart';

var host = dotenv.env['HOST'];
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
