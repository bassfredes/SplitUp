import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _hasSeenIntroKey = 'has_seen_intro';
  static SettingsService? _instance;
  late SharedPreferences _prefs;
  bool _initialized = false;

  // Private constructor
  SettingsService._();

  // Singleton accessor
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  Future<void> init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  bool get hasSeenIntro {
    if (!_initialized) {
      // Consider logging a warning or throwing an error if accessed before init
      // For now, defaulting to false to ensure intro shows if not initialized.
      return false;
    }
    return _prefs.getBool(_hasSeenIntroKey) ?? false;
  }

  Future<void> setHasSeenIntro(bool value) async {
    if (!_initialized) {
      await init(); // Ensure initialized before setting
    }
    await _prefs.setBool(_hasSeenIntroKey, value);
  }
}
