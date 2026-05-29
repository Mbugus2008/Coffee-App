import '../services/bc/bc_services.dart';
import 'daily_collection_model.dart';

class DailyCollectionApi {
  int _stablePositiveHash(String input) {
    var hash = 0;
    for (final codeUnit in input.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

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

    String s(List<String> keys) {
      final v = pick(keys);
      if (v == null) return '';
      if (v is String) return v;
      if (v is bool) return v ? 'Yes' : 'No';
      return v.toString();
    }

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
    final collectionNumber = s(['Collection_Number', 'CollectionNumber']);
    final parsedNo = i(['Collection_No', 'No_', 'No', 'No.']);
    final fallbackNo =
        int.tryParse(collectionNumber) ??
        _stablePositiveHash(
          collectionNumber.isEmpty
              ? collectionsDate.toIso8601String()
              : collectionNumber,
        );

    return DailyCollection(
      farmersNumber: s(['Farmers_Number', 'FarmersNumber']),
      collectionsDate: collectionsDate,
      collectionNumber: collectionNumber,
      coffeeType: s(['Coffee_Type', 'CoffeeType']),
      no: parsedNo == 0 ? fallbackNo : parsedNo,
      farmersName: s(['Farmers_Name', 'FarmersName']),
      kgCollected: d(['Kg__Collected', 'Kg_Collected', 'Kg Collected']),
      cancelled: s(['Cancelled']),
      paid: (() {
        final v = pick(['Paid']);
        if (v is bool) return v ? 1 : 0;
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v);
        return null;
      })(),
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
      noOfBags: (() {
        final v = pick(['No_of_Bags', 'NoOfBags']);
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v);
        return null;
      })(),
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
