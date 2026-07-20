class PartnerProfile {
  String name;
  String email;
  String phone;
  double rating;
  int totalDeliveries;

  PartnerProfile({
    required this.name,
    required this.email,
    required this.phone,
    this.rating = 5.0,
    this.totalDeliveries = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'rating': rating,
        'totalDeliveries': totalDeliveries,
      };

  factory PartnerProfile.fromJson(Map<String, dynamic> json) =>
      PartnerProfile(
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        rating: (json['rating'] as num).toDouble(),
        totalDeliveries: json['totalDeliveries'] as int,
      );
}
