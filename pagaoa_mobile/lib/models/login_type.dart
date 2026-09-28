// Which backend the current session came from. Saved with the session so the
// other screens know how to behave.

enum LoginType { dummyJson, firebase }

extension LoginTypeX on LoginType {
  /// Label shown on the UI chips and toggles.
  String get label => this == LoginType.firebase ? 'Firebase' : 'DummyJSON';

  /// Unknown or empty falls back to dummyJson.
  static LoginType fromName(String? name) =>
      LoginType.values.asNameMap()[name] ?? LoginType.dummyJson;
}
