import 'package:flutter_dotenv/flutter_dotenv.dart';

var host = dotenv.env['HOST'];
const int demoUserId = 1;
const List<Map<String, String>> demoAccounts = [
  {'username': 'emilys', 'password': 'emilyspass'},
  {'username': 'michaelw', 'password': 'michaelwpass'},
  {'username': 'sophiab', 'password': 'sophiabpass'},
];
