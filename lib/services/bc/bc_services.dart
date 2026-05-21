import '../../data/daily_collection_model.dart';
import '../../data/store_models.dart';
import 'bc_odata_client.dart';
import 'bc_settings_store.dart';

class BcServices {
  BcServices._();

  static final BcServices instance = BcServices._();

  final BcODataClient _client = BcODataClient();

  Future<List<Map<String, Object?>>> fetchCoffeeTypes() async {
    final settings = await BcSettingsStore.instance.load();
    return _client.getAll(settings, 'CoffeeTypes');
  }

  Future<List<Map<String, Object?>>> fetchFactories() async {
    final settings = await BcSettingsStore.instance.load();
    return _client.getAll(settings, 'Factories');
  }

  Future<List<Map<String, Object?>>> fetchUsers() async {
    final settings = await BcSettingsStore.instance.load();
    return _client.getAll(settings, 'Users');
  }

  Future<Map<String, Object?>> createUser({
    required String name,
    required String password,
    required String type,
  }) async {
    final settings = await BcSettingsStore.instance.load();
    return _client.create(settings, 'Users', {
      'Name': name,
      'Password': password,
      'Type': type,
    });
  }

  Future<void> updateUser({
    required String odataId,
    required Map<String, Object?> changes,
    String? etag,
  }) async {
    final settings = await BcSettingsStore.instance.load();
    await _client.patchByOdataId(settings, odataId, changes, etag: etag);
  }

  Future<List<Map<String, Object?>>> fetchDailyCollections() async {
    final settings = await BcSettingsStore.instance.load();
    final factory = settings.factory.trim();
    if (factory.isEmpty) {
      return [];
    }

    final escapedFactory = factory.replaceAll("'", "''");
    return _client.getAll(
      settings,
      'DailyCollections',
      query: {
        // OData v4 filter syntax.
        '\$filter': "Factory eq '$escapedFactory'",
      },
    );
  }

  Future<Map<String, Object?>> createDailyCollection(
    DailyCollection item,
  ) async {
    final settings = await BcSettingsStore.instance.load();
    return _client.create(
      settings,
      'DailyCollections',
      _dailyCollectionPayload(item),
    );
  }

  Future<Map<String, Object?>> createStoreHeader(StoreHeader item) async {
    final settings = await BcSettingsStore.instance.load();
    return _client.create(settings, 'StoreHeader', _storeHeaderPayload(item));
  }

  Future<Map<String, Object?>> createStoreLine(Store item) async {
    final settings = await BcSettingsStore.instance.load();
    return _client.create(settings, 'StoreLines', _storeLinePayload(item));
  }

  Map<String, Object?> _dailyCollectionPayload(DailyCollection item) {
    return {
      'No': item.no,
      'Farmers_Number': item.farmersNumber,
      'Farmers_Name': item.farmersName,
      'Collections_Date': _formatBcDate(item.collectionsDate),
      'Collection_Time': _formatBcDateTimeOffset(
        item.collectionTime ?? item.collectionsDate,
      ),
      'Collection_Number': item.collectionNumber,
      'Coffee_Type': item.coffeeType,
      'Kg_Collected': item.kgCollected ?? 0,
      'Gross': item.gross ?? 0,
      'Tare': item.tare ?? 0,
      'No_of_Bags': item.noOfBags ?? 0,
      'Factory': item.factory,
      'Cancelled': _boolFromFlag(item.cancelled),
      'Paid': _boolFromInt(item.paid),
      'Sent': item.sent ?? false,
      'Updated': item.updated ?? false,
      'ID_Number': item.idNumber,
      'Delivered_By': item.deliveredBy,
      'Collect_Type': item.collectType,
      'Crop': item.crop,
      'Cumm': item.cumm ?? 0,
      'Can': item.can,
      'User': item.userName,
      'Comments': item.comments,
    };
  }

  Map<String, Object?> _storeHeaderPayload(StoreHeader item) {
    return {
      if (item.id != null) 'No': item.id,
      'Client': item.client,
      'Date': item.date == null ? null : _formatBcDate(item.date!),
      'Entry': item.entry,
      'Total': item.total ?? 0,
      'Posted': item.posted ?? false,
      'Paymode': _paymodeToOption(item.paymode),
      'Amount_Paid': item.amountPaid ?? 0,
      'Balance': item.balance ?? 0,
      'Limit': item.limit ?? 0,
      'Stores': item.stores ?? 0,
      'Limit_Available': item.limitAvailable ?? 0,
      'Collector': item.collector,
      'Collector_No': item.collectorNo,
      'Member_Name': item.memberName,
      'Collector_is_Member': item.collectorIsMember ?? false,
      'Mpesa_Code': item.mpesaCode,
      'Mpesa_No': item.mpesaNo,
      'Mpesa_Name': item.mpesaName,
      'Crop_Year': item.cropYear,
      'Factory': item.factory,
      'Factory_Name': item.factoryName,
      'Served_By': item.servedBy,
      'Sent': item.sent ?? false,
      'Credit_Amount': item.creditAmount ?? 0,
      'Comments': item.comments,
      'Reversed': item.reversed ?? false,
      'Item_Count': item.itemCount ?? 0,
      'Updated': false,
    };
  }

  Map<String, Object?> _storeLinePayload(Store item) {
    return {
      if (item.id != null) 'No': item.id,
      'Entry': item.entry,
      'Client': item.client,
      'Item': item.item,
      'Item_Description': item.itemDescription,
      'Variant': item.variant,
      'Amount': item.amount ?? 0,
      'Quantity': item.quantity ?? 0,
      'Time': item.time == null ? null : _formatBcDateTimeOffset(item.time!),
      'Date': item.date == null ? null : _formatBcDate(item.date!),
      'Served_By': item.servedBy,
      'Status': item.status,
      'Factory': item.factory,
      'Sent': item.sent ?? false,
      'Comments': item.comments,
      'Line_Total': item.lineTotal ?? 0,
      'Stock': item.stock,
      'Crop': item.crop,
      'Balance': item.balance ?? 0,
      'Paymode': _paymodeToOption(item.paymode),
      'Amount_Paid': item.amountPaid ?? 0,
      'Updated': false,
    };
  }

  static String _formatBcDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _formatBcDateTimeOffset(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  static bool _boolFromFlag(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'y' || normalized == 'yes' || normalized == 'true';
  }

  static bool _boolFromInt(int? value) {
    return value == 1;
  }

  static String _paymodeToOption(int? paymode) {
    if (paymode == 0) {
      return 'Cash';
    }
    if (paymode == 1) {
      return 'Credit';
    }
    return ' ';
  }
}
