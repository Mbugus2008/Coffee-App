import 'package:shared_preferences/shared_preferences.dart';

import 'bc_settings.dart';

class BcSettingsStore {
  BcSettingsStore._();

  static final BcSettingsStore instance = BcSettingsStore._();

  static const _kBaseUrl = 'bc.odataBaseUrl';
  static const _kCompany = 'bc.company';
  static const _kUsername = 'bc.username';
  static const _kPassword = 'bc.password';
  static const _kFactory = 'bc.factory';

  Future<BcSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BcSettings(
      odataBaseUrl:
          prefs.getString(_kBaseUrl) ?? BcSettings.defaults.odataBaseUrl,
      company: prefs.getString(_kCompany) ?? BcSettings.defaults.company,
      username: prefs.getString(_kUsername) ?? BcSettings.defaults.username,
      password: prefs.getString(_kPassword) ?? BcSettings.defaults.password,
      factory: prefs.getString(_kFactory) ?? BcSettings.defaults.factory,
    );
  }

  Future<void> save(BcSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, settings.odataBaseUrl.trim());
    await prefs.setString(_kCompany, settings.company.trim());
    await prefs.setString(_kUsername, settings.username.trim());
    await prefs.setString(_kPassword, settings.password);
    await prefs.setString(_kFactory, settings.factory.trim());
  }
}
