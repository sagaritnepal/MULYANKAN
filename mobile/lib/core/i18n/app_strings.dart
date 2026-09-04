/// Hand-rolled localisation rather than `flutter_localizations` + ARB
/// codegen: the string set is small, and a plain typed class means a
/// missing translation is a compile error instead of a silent fallback
/// to the key at runtime.
///
/// Coverage is deliberately partial while Phase 3 is in progress — see
/// mobile/README.md. Screens not yet translated read their copy
/// literally and stay English; nothing breaks, they just don't switch.
library;

enum AppLocale {
  en('en', 'English'),
  ne('ne', 'नेपाली');

  const AppLocale(this.code, this.label);

  /// Stored on the User record as `language` (see prisma schema) and
  /// persisted locally by LanguageStorage.
  final String code;

  /// Always shown in the language's own script, never translated.
  final String label;

  static AppLocale fromCode(String? code) =>
      AppLocale.values.firstWhere((l) => l.code == code, orElse: () => AppLocale.en);
}

abstract class AppStrings {
  const AppStrings();

  static const Map<AppLocale, AppStrings> _byLocale = {
    AppLocale.en: _EnStrings(),
    AppLocale.ne: _NeStrings(),
  };

  static AppStrings of(AppLocale locale) => _byLocale[locale] ?? const _EnStrings();

  // Auth
  String get logIn;
  String get signUp;
  String get emailAddress;
  String get password;
  String get fullNameOptional;
  String get show;
  String get hide;
  String get forgotPassword;
  String get or;
  String get logInWithPhone;
  String get noAccountPrompt;
  String get haveAccountPrompt;
  String get enterBothFields;
  String get couldNotSignIn;
}

class _EnStrings extends AppStrings {
  const _EnStrings();

  @override
  String get logIn => 'Log in';
  @override
  String get signUp => 'Sign up';
  @override
  String get emailAddress => 'Email address';
  @override
  String get password => 'Password';
  @override
  String get fullNameOptional => 'Full name (optional)';
  @override
  String get show => 'Show';
  @override
  String get hide => 'Hide';
  @override
  String get forgotPassword => 'Forgot password?';
  @override
  String get or => 'OR';
  @override
  String get logInWithPhone => 'Log in with phone number';
  @override
  String get noAccountPrompt => "Don't have an account? ";
  @override
  String get haveAccountPrompt => 'Already have an account? ';
  @override
  String get enterBothFields => 'Enter both email and password';
  @override
  String get couldNotSignIn => 'Could not sign in';
}

/// Nepali copy drafted here and NOT yet reviewed by a native speaker —
/// see the note in mobile/README.md. The trade terms in particular
/// (मूल्यांकन, सवारी) should be checked against what dealers actually say.
class _NeStrings extends AppStrings {
  const _NeStrings();

  @override
  String get logIn => 'लग इन';
  @override
  String get signUp => 'साइन अप';
  @override
  String get emailAddress => 'इमेल ठेगाना';
  @override
  String get password => 'पासवर्ड';
  @override
  String get fullNameOptional => 'पूरा नाम (वैकल्पिक)';
  @override
  String get show => 'देखाउने';
  @override
  String get hide => 'लुकाउने';
  @override
  String get forgotPassword => 'पासवर्ड बिर्सनुभयो?';
  @override
  String get or => 'वा';
  @override
  String get logInWithPhone => 'फोन नम्बरबाट लग इन';
  @override
  String get noAccountPrompt => 'खाता छैन? ';
  @override
  String get haveAccountPrompt => 'पहिले नै खाता छ? ';
  @override
  String get enterBothFields => 'इमेल र पासवर्ड दुवै भर्नुहोस्';
  @override
  String get couldNotSignIn => 'साइन इन गर्न सकिएन';
}
