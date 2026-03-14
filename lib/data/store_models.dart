class StoreHeader {
  final int? id;
  final String client;
  final DateTime? date;
  final String entry;
  final double? total;
  final bool? posted;
  final int? paymode;
  final double? amountPaid;
  final double? balance;
  final double? limit;
  final double? stores;
  final double? limitAvailable;
  final String collector;
  final String collectorNo;
  final String memberName;
  final bool? collectorIsMember;
  final String mpesaCode;
  final String mpesaNo;
  final String mpesaName;
  final String cropYear;
  final String factory;
  final String factoryName;
  final String servedBy;
  final bool? sent;
  final double? creditAmount;
  final String comments;
  final bool? reversed;
  final int? itemCount;

  const StoreHeader({
    this.id,
    required this.client,
    required this.date,
    required this.entry,
    required this.total,
    required this.posted,
    required this.paymode,
    required this.amountPaid,
    required this.balance,
    required this.limit,
    required this.stores,
    required this.limitAvailable,
    required this.collector,
    required this.collectorNo,
    required this.memberName,
    required this.collectorIsMember,
    required this.mpesaCode,
    required this.mpesaNo,
    required this.mpesaName,
    required this.cropYear,
    required this.factory,
    required this.factoryName,
    required this.servedBy,
    required this.sent,
    required this.creditAmount,
    required this.comments,
    required this.reversed,
    required this.itemCount,
  });

  StoreHeader copyWith({
    int? id,
    String? client,
    DateTime? date,
    String? entry,
    double? total,
    bool? posted,
    int? paymode,
    double? amountPaid,
    double? balance,
    double? limit,
    double? stores,
    double? limitAvailable,
    String? collector,
    String? collectorNo,
    String? memberName,
    bool? collectorIsMember,
    String? mpesaCode,
    String? mpesaNo,
    String? mpesaName,
    String? cropYear,
    String? factory,
    String? factoryName,
    String? servedBy,
    bool? sent,
    double? creditAmount,
    String? comments,
    bool? reversed,
    int? itemCount,
  }) {
    return StoreHeader(
      id: id ?? this.id,
      client: client ?? this.client,
      date: date ?? this.date,
      entry: entry ?? this.entry,
      total: total ?? this.total,
      posted: posted ?? this.posted,
      paymode: paymode ?? this.paymode,
      amountPaid: amountPaid ?? this.amountPaid,
      balance: balance ?? this.balance,
      limit: limit ?? this.limit,
      stores: stores ?? this.stores,
      limitAvailable: limitAvailable ?? this.limitAvailable,
      collector: collector ?? this.collector,
      collectorNo: collectorNo ?? this.collectorNo,
      memberName: memberName ?? this.memberName,
      collectorIsMember: collectorIsMember ?? this.collectorIsMember,
      mpesaCode: mpesaCode ?? this.mpesaCode,
      mpesaNo: mpesaNo ?? this.mpesaNo,
      mpesaName: mpesaName ?? this.mpesaName,
      cropYear: cropYear ?? this.cropYear,
      factory: factory ?? this.factory,
      factoryName: factoryName ?? this.factoryName,
      servedBy: servedBy ?? this.servedBy,
      sent: sent ?? this.sent,
      creditAmount: creditAmount ?? this.creditAmount,
      comments: comments ?? this.comments,
      reversed: reversed ?? this.reversed,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'ID': id,
      'Client': client,
      'Date': date?.toIso8601String(),
      'Entry': entry,
      'Total': total,
      'Posted': posted == null ? null : (posted! ? 1 : 0),
      'Paymode': paymode,
      'Amount_Paid': amountPaid,
      'Balance': balance,
      'Limit': limit,
      'Stores': stores,
      'Limit_Available': limitAvailable,
      'Collector': collector,
      'Collector_No': collectorNo,
      'Member_Name': memberName,
      'Collector_is_Member': collectorIsMember == null
          ? null
          : (collectorIsMember! ? 1 : 0),
      'Mpesa_Code': mpesaCode,
      'Mpesa_No': mpesaNo,
      'Mpesa_Name': mpesaName,
      'Crop_Year': cropYear,
      'Factory': factory,
      'Factory_Name': factoryName,
      'Served_By': servedBy,
      'Sent': sent == null ? null : (sent! ? 1 : 0),
      'Credit_Amount': creditAmount,
      'Comments': comments,
      'Reversed': reversed == null ? null : (reversed! ? 1 : 0),
      'Item_Count': itemCount,
    };
  }

  factory StoreHeader.fromMap(Map<String, Object?> map) {
    return StoreHeader(
      id: map['ID'] as int?,
      client: map['Client'] as String? ?? '',
      date: _toDateTime(map['Date']),
      entry: map['Entry'] as String? ?? '',
      total: (map['Total'] as num?)?.toDouble(),
      posted: _toBool(map['Posted']),
      paymode: map['Paymode'] as int?,
      amountPaid: (map['Amount_Paid'] as num?)?.toDouble(),
      balance: (map['Balance'] as num?)?.toDouble(),
      limit: (map['Limit'] as num?)?.toDouble(),
      stores: (map['Stores'] as num?)?.toDouble(),
      limitAvailable: (map['Limit_Available'] as num?)?.toDouble(),
      collector: map['Collector'] as String? ?? '',
      collectorNo: map['Collector_No'] as String? ?? '',
      memberName: map['Member_Name'] as String? ?? '',
      collectorIsMember: _toBool(map['Collector_is_Member']),
      mpesaCode: map['Mpesa_Code'] as String? ?? '',
      mpesaNo: map['Mpesa_No'] as String? ?? '',
      mpesaName: map['Mpesa_Name'] as String? ?? '',
      cropYear: map['Crop_Year'] as String? ?? '',
      factory: map['Factory'] as String? ?? '',
      factoryName: map['Factory_Name'] as String? ?? '',
      servedBy: map['Served_By'] as String? ?? '',
      sent: _toBool(map['Sent']),
      creditAmount: (map['Credit_Amount'] as num?)?.toDouble(),
      comments: map['Comments'] as String? ?? '',
      reversed: _toBool(map['Reversed']),
      itemCount: map['Item_Count'] as int?,
    );
  }

  static DateTime? _toDateTime(Object? value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static bool? _toBool(Object? value) {
    if (value == null) return null;
    if (value is int) return value == 1;
    if (value is bool) return value;
    return null;
  }
}

class Store {
  final int? id;
  final String entry;
  final String client;
  final String item;
  final String variant;
  final double? amount;
  final double? quantity;
  final DateTime? time;
  final DateTime? date;
  final String servedBy;
  final String status;
  final String factory;
  final bool? sent;
  final String comments;
  final double? lineTotal;
  final String stock;
  final String crop;
  final int? balance;
  final int? paymode;
  final double? amountPaid;

  const Store({
    this.id,
    required this.entry,
    required this.client,
    required this.item,
    required this.variant,
    required this.amount,
    required this.quantity,
    required this.time,
    required this.date,
    required this.servedBy,
    required this.status,
    required this.factory,
    required this.sent,
    required this.comments,
    required this.lineTotal,
    required this.stock,
    required this.crop,
    required this.balance,
    required this.paymode,
    required this.amountPaid,
  });

  Map<String, Object?> toMap() {
    return {
      'ID': id,
      'Entry': entry,
      'Client': client,
      'Item': item,
      'Variant': variant,
      'Amount': amount,
      'Quantity': quantity,
      'Time': time?.toIso8601String(),
      'Date': date?.toIso8601String(),
      'Served_By': servedBy,
      'Status': status,
      'Factory': factory,
      'Sent': sent == null ? null : (sent! ? 1 : 0),
      'Comments': comments,
      'Line_total': lineTotal,
      'Stock': stock,
      'Crop': crop,
      'Balance': balance,
      'Paymode': paymode,
      'Amount_Paid': amountPaid,
    };
  }

  factory Store.fromMap(Map<String, Object?> map) {
    return Store(
      id: map['ID'] as int?,
      entry: map['Entry'] as String? ?? '',
      client: map['Client'] as String? ?? '',
      item: map['Item'] as String? ?? '',
      variant: map['Variant'] as String? ?? '',
      amount: (map['Amount'] as num?)?.toDouble(),
      quantity: (map['Quantity'] as num?)?.toDouble(),
      time: StoreHeader._toDateTime(map['Time']),
      date: StoreHeader._toDateTime(map['Date']),
      servedBy: map['Served_By'] as String? ?? '',
      status: map['Status'] as String? ?? '',
      factory: map['Factory'] as String? ?? '',
      sent: StoreHeader._toBool(map['Sent']),
      comments: map['Comments'] as String? ?? '',
      lineTotal: (map['Line_total'] as num?)?.toDouble(),
      stock: map['Stock'] as String? ?? '',
      crop: map['Crop'] as String? ?? '',
      balance: map['Balance'] as int?,
      paymode: map['Paymode'] as int?,
      amountPaid: (map['Amount_Paid'] as num?)?.toDouble(),
    );
  }
}

class Item {
  final String no;
  final String description;
  final String baseUnitOfMeasure;
  final double? lastDirectCost;
  final double? unitCost;
  final double? unitPrice;
  final double? inventory;
  final int? preventNegativeInventory;

  const Item({
    required this.no,
    required this.description,
    required this.baseUnitOfMeasure,
    required this.lastDirectCost,
    required this.unitCost,
    required this.unitPrice,
    required this.inventory,
    required this.preventNegativeInventory,
  });

  Map<String, Object?> toMap() {
    return {
      'No': no,
      'Description': description,
      'Base_Unit_of_Measure': baseUnitOfMeasure,
      'Last_Direct_Cost': lastDirectCost,
      'Unit_Cost': unitCost,
      'Unit_Price': unitPrice,
      'Inventory': inventory,
      'Prevent_Negative_Inventory': preventNegativeInventory,
    };
  }

  factory Item.fromMap(Map<String, Object?> map) {
    return Item(
      no: map['No'] as String? ?? '',
      description: map['Description'] as String? ?? '',
      baseUnitOfMeasure: map['Base_Unit_of_Measure'] as String? ?? '',
      lastDirectCost: (map['Last_Direct_Cost'] as num?)?.toDouble(),
      unitCost: (map['Unit_Cost'] as num?)?.toDouble(),
      unitPrice: (map['Unit_Price'] as num?)?.toDouble(),
      inventory: (map['Inventory'] as num?)?.toDouble(),
      preventNegativeInventory: map['Prevent_Negative_Inventory'] as int?,
    );
  }
}
