import '../data/collection_settings_model.dart';
import '../data/user_database.dart';

class CollectionSettingsService {
  CollectionSettingsService._();

  static final CollectionSettingsService instance =
      CollectionSettingsService._();

  Future<CollectionSettings> load() async {
    return UserDatabase.instance.getCollectionSettings();
  }

  Future<void> save(CollectionSettings settings) async {
    await UserDatabase.instance.saveCollectionSettings(settings);
  }
}