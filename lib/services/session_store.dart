import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();

  static const _kCurrentUsername = 'session.currentUsername';
  static const _kRememberedUsername = 'session.rememberedUsername';
  static const _kRememberedDate = 'session.rememberedDate';
  static const _kLastUsername = 'session.lastUsername';

  Future<String?> getCurrentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kCurrentUsername)?.trim() ?? '';
    if (value.isEmpty) return null;
    return value;
  }

  Future<void> setCurrentUsername(String username) async {
    final value = username.trim();
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await prefs.remove(_kCurrentUsername);
      return;
    }
    await prefs.setString(_kCurrentUsername, value);
  }

  Future<void> startSession({
    required String username,
    required bool rememberMe,
  }) async {
    final value = username.trim();
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await clearSession();
      return;
    }

    await prefs.setString(_kCurrentUsername, value);
    await prefs.setString(_kLastUsername, value);
    if (!rememberMe) {
      await prefs.remove(_kRememberedUsername);
      await prefs.remove(_kRememberedDate);
      return;
    }

    await prefs.setString(_kRememberedUsername, value);
    await prefs.setString(_kRememberedDate, _todayKey());
  }

  Future<String?> getRememberedUsernameForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_kRememberedUsername)?.trim() ?? '';
    final storedDate = prefs.getString(_kRememberedDate)?.trim() ?? '';
    if (username.isEmpty || storedDate.isEmpty) {
      return null;
    }
    if (storedDate != _todayKey()) {
      await clearSession();
      return null;
    }
    return username;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentUsername);
    await prefs.remove(_kRememberedUsername);
    await prefs.remove(_kRememberedDate);
  }

  Future<String?> getLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kLastUsername)?.trim() ?? '';
    if (value.isEmpty) return null;
    return value;
  }

  String _todayKey() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
