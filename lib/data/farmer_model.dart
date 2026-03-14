class Farmer {
  final String no;
  final String name;
  final String phone;
  final String email;
  final String idNo;
  final double? cumCherry;
  final double? cumMbuni;
  final bool? updated;
  final int? accountCategory;
  final String factory;
  final String comments;
  final bool? gender;
  final String bank;
  final String bankAccount;
  final double? acreage;
  final int? noOfTrees;
  final double? otherLoans;
  final double? previousCropCollection;
  final double? limitPercentage;
  final double? limit;
  final double? totalStores;
  final double? currentCropCollectionCherry1;
  final double? currentCropCollectionCherry2;
  final double? currentCropCollection;
  final String bankCode;
  final String bankName;

  const Farmer({
    required this.no,
    required this.name,
    required this.phone,
    required this.email,
    required this.idNo,
    required this.cumCherry,
    required this.cumMbuni,
    required this.updated,
    required this.accountCategory,
    required this.factory,
    required this.comments,
    required this.gender,
    required this.bank,
    required this.bankAccount,
    required this.acreage,
    required this.noOfTrees,
    required this.otherLoans,
    required this.previousCropCollection,
    required this.limitPercentage,
    required this.limit,
    required this.totalStores,
    required this.currentCropCollectionCherry1,
    required this.currentCropCollectionCherry2,
    required this.currentCropCollection,
    required this.bankCode,
    required this.bankName,
  });

  Farmer copyWith({
    String? no,
    String? name,
    String? phone,
    String? email,
    String? idNo,
    double? cumCherry,
    double? cumMbuni,
    bool? updated,
    int? accountCategory,
    String? factory,
    String? comments,
    bool? gender,
    String? bank,
    String? bankAccount,
    double? acreage,
    int? noOfTrees,
    double? otherLoans,
    double? previousCropCollection,
    double? limitPercentage,
    double? limit,
    double? totalStores,
    double? currentCropCollectionCherry1,
    double? currentCropCollectionCherry2,
    double? currentCropCollection,
    String? bankCode,
    String? bankName,
  }) {
    return Farmer(
      no: no ?? this.no,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      idNo: idNo ?? this.idNo,
      cumCherry: cumCherry ?? this.cumCherry,
      cumMbuni: cumMbuni ?? this.cumMbuni,
      updated: updated ?? this.updated,
      accountCategory: accountCategory ?? this.accountCategory,
      factory: factory ?? this.factory,
      comments: comments ?? this.comments,
      gender: gender ?? this.gender,
      bank: bank ?? this.bank,
      bankAccount: bankAccount ?? this.bankAccount,
      acreage: acreage ?? this.acreage,
      noOfTrees: noOfTrees ?? this.noOfTrees,
      otherLoans: otherLoans ?? this.otherLoans,
      previousCropCollection:
          previousCropCollection ?? this.previousCropCollection,
      limitPercentage: limitPercentage ?? this.limitPercentage,
      limit: limit ?? this.limit,
      totalStores: totalStores ?? this.totalStores,
      currentCropCollectionCherry1:
          currentCropCollectionCherry1 ?? this.currentCropCollectionCherry1,
      currentCropCollectionCherry2:
          currentCropCollectionCherry2 ?? this.currentCropCollectionCherry2,
      currentCropCollection:
          currentCropCollection ?? this.currentCropCollection,
      bankCode: bankCode ?? this.bankCode,
      bankName: bankName ?? this.bankName,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'No': no,
      'Name': name,
      'Phone': phone,
      'Email': email,
      'ID_No': idNo,
      'Cum_Cherry': cumCherry,
      'Cum_Mbuni': cumMbuni,
      'Updated': updated == null ? null : (updated! ? 1 : 0),
      'Account_Category': accountCategory,
      'Factory': factory,
      'Comments': comments,
      'Gender': gender == null ? null : (gender! ? 1 : 0),
      'Bank': bank,
      'Bank_Account': bankAccount,
      'Acreage': acreage,
      'No_of_Trees': noOfTrees,
      'Other_Loans': otherLoans,
      'Previous_Crop_collection': previousCropCollection,
      'Limit_percentage': limitPercentage,
      'Limit': limit,
      'Total_Stores': totalStores,
      'Current_Crop_collection_Cherry_1': currentCropCollectionCherry1,
      'Current_Crop_collection_Cherry_2': currentCropCollectionCherry2,
      'Current_Crop_collection': currentCropCollection,
      'Bank_Code': bankCode,
      'Bank_Name': bankName,
    };
  }

  factory Farmer.fromMap(Map<String, Object?> map) {
    return Farmer(
      no: map['No'] as String? ?? '',
      name: map['Name'] as String? ?? '',
      phone: map['Phone'] as String? ?? '',
      email: map['Email'] as String? ?? '',
      idNo: map['ID_No'] as String? ?? '',
      cumCherry: (map['Cum_Cherry'] as num?)?.toDouble(),
      cumMbuni: (map['Cum_Mbuni'] as num?)?.toDouble(),
      updated: _toBool(map['Updated']),
      accountCategory: map['Account_Category'] as int?,
      factory: map['Factory'] as String? ?? '',
      comments: map['Comments'] as String? ?? '',
      gender: _toBool(map['Gender']),
      bank: map['Bank'] as String? ?? '',
      bankAccount: map['Bank_Account'] as String? ?? '',
      acreage: (map['Acreage'] as num?)?.toDouble(),
      noOfTrees: map['No_of_Trees'] as int?,
      otherLoans: (map['Other_Loans'] as num?)?.toDouble(),
      previousCropCollection: (map['Previous_Crop_collection'] as num?)
          ?.toDouble(),
      limitPercentage: (map['Limit_percentage'] as num?)?.toDouble(),
      limit: (map['Limit'] as num?)?.toDouble(),
      totalStores: (map['Total_Stores'] as num?)?.toDouble(),
      currentCropCollectionCherry1:
          (map['Current_Crop_collection_Cherry_1'] as num?)?.toDouble(),
      currentCropCollectionCherry2:
          (map['Current_Crop_collection_Cherry_2'] as num?)?.toDouble(),
      currentCropCollection: (map['Current_Crop_collection'] as num?)
          ?.toDouble(),
      bankCode: map['Bank_Code'] as String? ?? '',
      bankName: map['Bank_Name'] as String? ?? '',
    );
  }

  static bool? _toBool(Object? value) {
    if (value == null) return null;
    if (value is int) return value == 1;
    if (value is bool) return value;
    return null;
  }
}
