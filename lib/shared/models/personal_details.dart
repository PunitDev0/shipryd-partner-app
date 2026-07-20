// ---- Onboarding: personal details (Step 3) ----
class PersonalDetails {
  DateTime? dob;
  String? gender;
  String emergencyContact;
  String address;
  String city;
  String state;
  String pincode;
  String preferredLanguage;

  PersonalDetails({
    this.dob,
    this.gender,
    this.emergencyContact = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.preferredLanguage = 'English',
  });

  Map<String, dynamic> toJson() => {
        'dob': dob?.toIso8601String(),
        'gender': gender,
        'emergencyContact': emergencyContact,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'preferredLanguage': preferredLanguage,
      };

  factory PersonalDetails.fromJson(Map<String, dynamic> json) => PersonalDetails(
        dob: json['dob'] != null ? DateTime.parse(json['dob'] as String) : null,
        gender: json['gender'] as String?,
        emergencyContact: json['emergencyContact'] as String? ?? '',
        address: json['address'] as String? ?? '',
        city: json['city'] as String? ?? '',
        state: json['state'] as String? ?? '',
        pincode: json['pincode'] as String? ?? '',
        preferredLanguage: json['preferredLanguage'] as String? ?? 'English',
      );
}
