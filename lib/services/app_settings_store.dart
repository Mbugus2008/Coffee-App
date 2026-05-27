import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsStore {
  AppSettingsStore._();

  static final AppSettingsStore instance = AppSettingsStore._();

  static const _kShowCumulative = 'app.showCumulative';

  static const showCumulativeOptions = <String>[
    'On Receipt',
    'On SMS',
    'Both',
  ];

  Future<String> loadShowCumulative() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_kShowCumulative) ?? '';
    if (showCumulativeOptions.contains(value)) return value;
    return showCumulativeOptions.first;
  }

  Future<void> saveShowCumulative(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kShowCumulative, value.trim());
  }
}
