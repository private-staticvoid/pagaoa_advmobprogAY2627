// LAB 5 — LoginType
// Tells the app WHICH backend the current session came from.
//   dummyJson -> https://dummyjson.com/auth/login (mock API, demo accounts)
//   firebase  -> FirebaseAuth email/password (real accounts)
//
// It is saved in SharedPreferences next to the rest of the session, so the
// splash screen, profile screen and logout all know which backend to use.

enum LoginType { dummyJson, firebase }

extension LoginTypeX on LoginType {
  /// Human-friendly label for the UI (chips, toggles).
  String get label => this == LoginType.firebase ? 'Firebase' : 'DummyJSON';

  /// Turns the saved string back into an enum. Unknown/empty -> dummyJson,
  /// because every session saved before Lab 5 was a DummyJSON session.
  static LoginType fromName(String? name) =>
      LoginType.values.asNameMap()[name] ?? LoginType.dummyJson;
}
