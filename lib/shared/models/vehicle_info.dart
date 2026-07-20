class VehicleInfo {
  String type;
  String number;
  String? brand;
  String? model;
  String? fuelType;
  int? year;

  VehicleInfo({
    required this.type,
    required this.number,
    this.brand,
    this.model,
    this.fuelType,
    this.year,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'number': number,
        'brand': brand,
        'model': model,
        'fuelType': fuelType,
        'year': year,
      };

  factory VehicleInfo.fromJson(Map<String, dynamic> json) => VehicleInfo(
        type: json['type'] as String,
        number: json['number'] as String,
        brand: json['brand'] as String?,
        model: json['model'] as String?,
        fuelType: json['fuelType'] as String?,
        year: json['year'] as int?,
      );
}
