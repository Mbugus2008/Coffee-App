class CollectionSettings {
  final String crop;
  final String coffeeType;
  final double tareWeight;

  const CollectionSettings({
    required this.crop,
    required this.coffeeType,
    required this.tareWeight,
  });

  static const defaults = CollectionSettings(
    crop: '',
    coffeeType: '',
    tareWeight: 0,
  );

  CollectionSettings copyWith({
    String? crop,
    String? coffeeType,
    double? tareWeight,
  }) {
    return CollectionSettings(
      crop: crop ?? this.crop,
      coffeeType: coffeeType ?? this.coffeeType,
      tareWeight: tareWeight ?? this.tareWeight,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'ID': 1,
      'Crop': crop,
      'Coffee_Type': coffeeType,
      'Tare_Weight': tareWeight,
    };
  }

  factory CollectionSettings.fromMap(Map<String, Object?> map) {
    return CollectionSettings(
      crop: (map['Crop'] as String?) ?? '',
      coffeeType: (map['Coffee_Type'] as String?) ?? '',
      tareWeight: (map['Tare_Weight'] as num?)?.toDouble() ?? 0,
    );
  }
}
