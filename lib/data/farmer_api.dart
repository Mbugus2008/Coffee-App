import '../services/bc/bc_odata_client.dart';
import '../services/bc/bc_settings_store.dart';
import 'farmer_model.dart';

class FarmerApi {
  FarmerApi({BcODataClient? client}) : _client = client ?? BcODataClient();

  final BcODataClient _client;

  Future<void> createFarmer(Farmer farmer) async {
    final settings = await BcSettingsStore.instance.load();
    await _client.create(settings, 'Farmers', _farmerPayload(farmer));
  }

  Future<void> updateFarmer(Farmer farmer) async {
    final settings = await BcSettingsStore.instance.load();
    final payload = _farmerPayload(farmer);

    try {
      await _client.patchBySingleKey(settings, 'Farmers', farmer.no, payload);
      return;
    } catch (_) {
      // Fall back to resolving @odata.id by filter when key-based PATCH fails.
    }

    final odataId = await _resolveFarmerOdataId(farmer.no);
    if (odataId == null || odataId.isEmpty) {
      throw Exception('Farmer ${farmer.no} not found in BC.');
    }

    await _client.patchByOdataId(settings, odataId, payload);
  }

  Future<List<Farmer>> fetchFarmers() async {
    final settings = await BcSettingsStore.instance.load();
    if (settings.username.trim().isEmpty || settings.password.isEmpty) {
      return [];
    }

    final rows = await _client.getAll(settings, 'Farmers', top: 5000);
    return rows.map(_mapToFarmer).toList();
  }

  Farmer _mapToFarmer(Map<String, Object?> json) {
    Object? pick(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key)) {
          return json[key];
        }
      }
      return null;
    }

    String s(List<String> keys) {
      final value = pick(keys);
      return value?.toString().trim() ?? '';
    }

    double? d(List<String> keys) {
      final value = pick(keys);
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim());
      return null;
    }

    int? i(List<String> keys) {
      final value = pick(keys);
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim());
      return null;
    }

    bool? b(List<String> keys) {
      final value = pick(keys);
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        final lower = value.trim().toLowerCase();
        if (lower == 'true' || lower == 'yes' || lower == 'y') return true;
        if (lower == 'false' || lower == 'no' || lower == 'n') return false;
      }
      return null;
    }

    return Farmer(
      no: s(['No', 'No_', 'No.']),
      name: s(['Name', 'FarmerName']),
      phone: s(['Phone_No', 'Phone No.', 'Phone']),
      email: s(['E_Mail', 'E-Mail', 'Email']),
      idNo: s(['VAT_Registration_No', 'VAT Registration No.', 'ID_No']),
      cumCherry: d(['Cumm_Cherry', 'Cum_Cherry', 'CumCherry']),
      cumMbuni: d(['Cumm_Mbuni', 'Cum_Mbuni', 'CumMbuni']),
      updated: b(['Updated']) ?? false,
      accountCategory: i(['Account_Category', 'AccountCategory']) ?? 1,
      factory: s(['Global_Dimension_Code', 'Global Dimension Code', 'Factory']),
      comments: s(['Comments']),
      gender: b(['Gender']),
      bank: s(['Bank']),
      bankAccount: s(['Bank_Account', 'Bank Account']),
      multipleDelivery: b([
        'Multiple_delivery',
        'Multiple_Delivery',
        'Multiple delivery',
      ]),
      acreage: d(['Acreage']),
      noOfTrees: i(['No_of_Trees', 'No of Trees']),
      otherLoans: d(['Other_Loans', 'Other Loans']),
      previousCropCollection: d([
        'Previous_Crop_collection',
        'Previous Crop collection',
      ]),
      limitPercentage: d(['Limit_percentage', 'Limit percentage']),
      limit: d(['Limit']),
      totalStores: d(['Total_Stores', 'Total Stores']),
      currentCropCollectionCherry1: d([
        'Current_Crop_collection_Cherry_1',
        'Current Crop collection Cherry 1',
      ]),
      currentCropCollectionCherry2: d([
        'Current_Crop_collection_Cherry_2',
        'Current Crop collection Cherry 2',
      ]),
      currentCropCollection: d([
        'Current_Crop_collection',
        'Current Crop collection',
      ]),
      bankCode: s(['Bank_Code', 'Bank Code']),
      bankName: s(['Bank_Name', 'Bank Name']),
    );
  }

  Future<String?> _resolveFarmerOdataId(String farmerNo) async {
    final settings = await BcSettingsStore.instance.load();
    final escapedNo = farmerNo.replaceAll("'", "''");
    final filters = <String>["No eq '$escapedNo'"];

    for (final filter in filters) {
      try {
        final rows = await _client.getAll(
          settings,
          'Farmers',
          top: 1,
          query: {'\$filter': filter},
        );
        if (rows.isEmpty) {
          continue;
        }
        final odataId = rows.first['@odata.id'];
        if (odataId is String && odataId.isNotEmpty) {
          return odataId;
        }
      } catch (_) {
        // Try the next filter key if this endpoint does not expose the field.
      }
    }

    return null;
  }

  Map<String, Object?> _farmerPayload(Farmer farmer) {
    return {
      'No': farmer.no,
      'Name': farmer.name,
      'Phone_No': farmer.phone,
      'ID_No': farmer.idNo,
      'Cumm_Cherry': farmer.cumCherry ?? 0,
      'Cumm_Mbuni': farmer.cumMbuni ?? 0,
      'Global_Dimension_Code': farmer.factory,
      'Multiple_delivery': farmer.multipleDelivery ?? false,
      'Acreage': farmer.acreage ?? 0,
      'No_of_Trees': farmer.noOfTrees ?? 0,
    };
  }
}
