import '../data/collection_settings_model.dart';
import '../data/user_database.dart';
import 'bc/bc_odata_client.dart';
import 'bc/bc_settings.dart';
import 'bc/bc_settings_store.dart';

class CollectionSettingsService {
  CollectionSettingsService._();

  static final CollectionSettingsService instance =
      CollectionSettingsService._();

  final BcODataClient _odataClient = BcODataClient();

  Future<CollectionSettings> load() async {
    return UserDatabase.instance.getCollectionSettings();
  }

  Future<void> save(CollectionSettings settings) async {
    await UserDatabase.instance.saveCollectionSettings(settings);
  }

  Future<CollectionSettings> syncFromBcSetup({
    BcSettings? overrideSettings,
    bool persistFactoryToStore = true,
  }) async {
    final settings = overrideSettings ?? await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      return load();
    }

    try {
      final rows = await _odataClient.getAll(settings, 'Setup', top: 1);
      if (rows.isEmpty) {
        return load();
      }

      final row = rows.first;
      final crop = _pickString(row, ['Crop', 'crop']);
      final coffeeType = _pickString(row, [
        'Coffee_Type',
        'Coffee Type',
        'CoffeeType',
        'coffeeType',
      ]);
      final tareWeight = _pickDouble(row, [
        'Tare_Weight',
        'Tare Weight',
        'TareWeight',
      ]);
      final factory = _pickString(row, [
        'Factory',
        'Factory_Name',
        'Factory Name',
      ]);

      final current = await load();
      final merged = current.copyWith(
        crop: crop.isNotEmpty ? crop : current.crop,
        coffeeType: coffeeType.isNotEmpty ? coffeeType : current.coffeeType,
        tareWeight: tareWeight ?? current.tareWeight,
      );
      await save(merged);

      if (persistFactoryToStore && factory.isNotEmpty) {
        final savedBc = await BcSettingsStore.instance.load();
        await BcSettingsStore.instance.save(savedBc.copyWith(factory: factory));
      }

      return merged;
    } catch (_) {
      return load();
    }
  }

  String _pickString(Map<String, Object?> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  double? _pickDouble(Map<String, Object?> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}