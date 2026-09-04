import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/i18n/app_strings.dart';

/// Reuses flutter_secure_storage rather than adding shared_preferences
/// for one key. A language choice is not a secret, but it is the only
/// key-value store already in the project and it works on web.
class LanguageStorage {
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_language';

  static Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      // A locked or unavailable keystore must not stop the app booting.
      return null;
    }
  }

  static Future<void> write(String code) async {
    try {
      await _storage.write(key: _key, value: code);
    } catch (_) {
      // Losing the preference is survivable; crashing on a toggle is not.
    }
  }
}

/// The chosen language is read back before the first frame so the login
/// screen does not flash English and then switch. The User record also
/// carries a `language` column; syncing the two is a later step, so for
/// now the local choice wins.
class LocaleNotifier extends StateNotifier<AppLocale> {
  LocaleNotifier() : super(AppLocale.en) {
    _restore();
  }

  Future<void> _restore() async {
    final code = await LanguageStorage.read();
    if (code != null) state = AppLocale.fromCode(code);
  }

  Future<void> set(AppLocale locale) async {
    if (locale == state) return;
    state = locale;
    await LanguageStorage.write(locale.code);
  }

  Future<void> toggle() =>
      set(state == AppLocale.en ? AppLocale.ne : AppLocale.en);
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, AppLocale>((ref) => LocaleNotifier());

/// What screens actually watch: `ref.watch(stringsProvider).logIn`.
final stringsProvider = Provider<AppStrings>(
  (ref) => AppStrings.of(ref.watch(localeProvider)),
);
