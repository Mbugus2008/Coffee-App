import '../services/bc/bc_services.dart';
import 'daily_collection_model.dart';

class DailyCollectionApi {
  Future<List<DailyCollection>> fetchDailyCollections() async {
    final rows = await BcServices.instance.fetchDailyCollections();
    return rows.map(_mapToDailyCollection).toList();
  }

  DailyCollection _mapToDailyCollection(Map<String, Object?> json) {
    Object? pick(List<String> keys) {
      for (final k in keys) {
        if (json.containsKey(k)) return json[k];
      }
      return null;
    }

    String s(List<String> keys) => (pick(keys) as String?) ?? '';

    int i(List<String> keys) {
      final v = pick(keys);
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double? d(List<String> keys) {
      final v = pick(keys);
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    bool? b(List<String> keys) {
      final v = pick(keys);
      if (v is bool) return v;
      if (v is int) return v == 1;
      if (v is String) {
        final low = v.toLowerCase();
        if (low == 'true' || low == 'yes' || low == 'y') return true;
        if (low == 'false' || low == 'no' || low == 'n') return false;
      }
      return null;
    }

    DateTime dt(List<String> keys, {DateTime? fallback}) {
      final v = pick(keys);
      if (v is DateTime) return v;
      if (v is String) {
        return DateTime.tryParse(v) ?? (fallback ?? DateTime(1970));
      }
      return fallback ?? DateTime(1970);
    }

    final collectionsDate = dt(['Collections_Date', 'CollectionsDate']);

    return DailyCollection(
      farmersNumber: s(['Farmers_Number', 'FarmersNumber']),
      collectionsDate: collectionsDate,
      collectionNumber: s(['Collection_Number', 'CollectionNumber']),
      coffeeType: s(['Coffee_Type', 'CoffeeType']),
      no: i(['No_', 'No', 'No.']),
      farmersName: s(['Farmers_Name', 'FarmersName']),
      kgCollected: d(['Kg__Collected', 'Kg_Collected', 'Kg Collected']),
      cancelled: s(['Cancelled']),
      paid: (pick(['Paid']) as num?)?.toInt(),
      idNumber: s(['ID_Number', 'IDNumber']),
      factory: s(['Factory']),
      sent: b(['Sent']),
      comments: s(['Comments']),
      cumm: d(['Cumm']),
      userName: s(['User', 'UserName']),
      can: s(['Can']),
      collectionTime: dt([
        'Collection_Time',
        'Collection_time',
        'CollectionTime',
      ], fallback: collectionsDate),
      collectType: s(['Collect_Type', 'Collect_type', 'CollectType']),
      crop: s(['Crop']),
      gross: d(['Gross']),
      tare: d(['Tare']),
      noOfBags: (pick(['No_of_Bags', 'NoOfBags']) as num?)?.toInt(),
      deliveredBy: s(['Delivered_By', 'DeliveredBy']),
      coffeTypeName: s([
        'Coffe_Type_Name',
        'Coffee_Type_Name',
        'CoffeeTypeName',
      ]),
      updated: b(['Updated']),
    );
  }
}
