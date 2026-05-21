import '../services/bc/bc_odata_client.dart';
import '../services/bc/bc_settings_store.dart';
import 'store_models.dart';

class ItemApi {
  ItemApi({BcODataClient? client}) : _client = client ?? BcODataClient();

  final BcODataClient _client;

  Future<List<Item>> fetchItems() async {
    final settings = await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      return [];
    }

    final rows = await _client.getAll(settings, 'Items', top: 5000);
    return rows
        .map(_mapToItem)
        .where((item) => item.no.trim().isNotEmpty)
        .toList();
  }

  Item _mapToItem(Map<String, Object?> row) {
    String str(String key) => (row[key] as String?)?.trim() ?? '';
    double? numAsDouble(String key) => (row[key] as num?)?.toDouble();

    return Item(
      no: str('No'),
      description: str('Description'),
      baseUnitOfMeasure: str('Base_Unit_of_Measure'),
      lastDirectCost: numAsDouble('Last_Direct_Cost'),
      unitCost: numAsDouble('Unit_Cost'),
      unitPrice: numAsDouble('Unit_Price'),
      inventory: numAsDouble('Inventory'),
      preventNegativeInventory: (row['Prevent_Negative_Inventory'] as num?)
          ?.toInt(),
    );
  }
}
