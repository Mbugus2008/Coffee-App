class CollectionSettings {
  final String crop;
  final double tareWeight;

  const CollectionSettings({required this.crop, required this.tareWeight});

  static const defaults = CollectionSettings(crop: '', tareWeight: 0);

  CollectionSettings copyWith({String? crop, double? tareWeight}) {
    return CollectionSettings(
      crop: crop ?? this.crop,
      tareWeight: tareWeight ?? this.tareWeight,
    );
  }

  Map<String, Object?> toMap() {
    return {'ID': 1, 'Crop': crop, 'Tare_Weight': tareWeight};
  }

  factory CollectionSettings.fromMap(Map<String, Object?> map) {
    return CollectionSettings(
      crop: (map['Crop'] as String?) ?? '',
      tareWeight: (map['Tare_Weight'] as num?)?.toDouble() ?? 0,
    );
  }
}