class DailyCollection {
  final String farmersNumber;
  final DateTime collectionsDate;
  final String collectionNumber;
  final String coffeeType;
  final int no;
  final String farmersName;
  final double? kgCollected;
  final String cancelled;
  final int? paid;
  final String idNumber;
  final String factory;
  final bool? sent;
  final String comments;
  final double? cumm;
  final String userName;
  final String can;
  final DateTime? collectionTime;
  final String collectType;
  final String crop;
  final double? gross;
  final double? tare;
  final int? noOfBags;
  final String deliveredBy;
  final String coffeTypeName;
  final bool? updated;

  const DailyCollection({
    required this.farmersNumber,
    required this.collectionsDate,
    required this.collectionNumber,
    required this.coffeeType,
    required this.no,
    required this.farmersName,
    required this.kgCollected,
    required this.cancelled,
    required this.paid,
    required this.idNumber,
    required this.factory,
    required this.sent,
    required this.comments,
    required this.cumm,
    required this.userName,
    required this.can,
    required this.collectionTime,
    required this.collectType,
    required this.crop,
    required this.gross,
    required this.tare,
    required this.noOfBags,
    required this.deliveredBy,
    required this.coffeTypeName,
    required this.updated,
  });

  Map<String, Object?> toMap() {
    return {
      'Farmers_Number': farmersNumber,
      'Collections_Date': collectionsDate.toIso8601String(),
      'Collection_Number': collectionNumber,
      'Coffee_Type': coffeeType,
      'No_': no,
      'Farmers_Name': farmersName,
      'Kg__Collected': kgCollected,
      'Cancelled': cancelled,
      'Paid': paid,
      'ID_Number': idNumber,
      'Factory': factory,
      'Sent': _boolToInt(sent),
      'Comments': comments,
      'Cumm': cumm,
      'User': userName,
      'Can': can,
      'Collection_time': (collectionTime ?? collectionsDate).toIso8601String(),
      'Collect_type': collectType,
      'Crop': crop,
      'Gross': gross,
      'Tare': tare,
      'No_of_Bags': noOfBags,
      'Delivered_By': deliveredBy,
      'Coffe_Type_Name': coffeTypeName,
      'Updated': _boolToInt(updated),
    };
  }

  factory DailyCollection.fromMap(Map<String, Object?> map) {
    return DailyCollection(
      farmersNumber: map['Farmers_Number'] as String? ?? '',
      collectionsDate: _parseDate(map['Collections_Date']) ?? DateTime(1970),
      collectionNumber: map['Collection_Number'] as String? ?? '',
      coffeeType: map['Coffee_Type'] as String? ?? '',
      no: (map['No_'] as int?) ?? 0,
      farmersName: map['Farmers_Name'] as String? ?? '',
      kgCollected: (map['Kg__Collected'] as num?)?.toDouble(),
      cancelled: map['Cancelled'] as String? ?? '',
      paid: map['Paid'] as int?,
      idNumber: map['ID_Number'] as String? ?? '',
      factory: map['Factory'] as String? ?? '',
      sent: _intToBool(map['Sent']),
      comments: map['Comments'] as String? ?? '',
      cumm: (map['Cumm'] as num?)?.toDouble(),
      userName: map['User'] as String? ?? '',
      can: map['Can'] as String? ?? '',
      collectionTime:
          _parseDate(map['Collection_time']) ??
          _parseDate(map['Collections_Date']),
      collectType: map['Collect_type'] as String? ?? '',
      crop: map['Crop'] as String? ?? '',
      gross: (map['Gross'] as num?)?.toDouble(),
      tare: (map['Tare'] as num?)?.toDouble(),
      noOfBags: map['No_of_Bags'] as int?,
      deliveredBy: map['Delivered_By'] as String? ?? '',
      coffeTypeName: map['Coffe_Type_Name'] as String? ?? '',
      updated: _intToBool(map['Updated']),
    );
  }

  static int? _boolToInt(bool? value) {
    if (value == null) return null;
    return value ? 1 : 0;
  }

  static bool? _intToBool(Object? value) {
    if (value == null) return null;
    if (value is int) return value == 1;
    if (value is bool) return value;
    return null;
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
