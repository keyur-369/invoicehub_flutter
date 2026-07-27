class Profile {
  final String id;
  final String userId;
  final String role;
  final String? shopName;
  final String? ownerName;
  final String? gstNumber;
  final String? mobile;
  final String? email;
  final String? address;
  final String? city;
  final String? logoUrl;
  final String? signatureUrl;
  final bool isProfileCompleted;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    required this.userId,
    required this.role,
    this.shopName,
    this.ownerName,
    this.gstNumber,
    this.mobile,
    this.email,
    this.address,
    this.city,
    this.logoUrl,
    this.signatureUrl,
    this.isProfileCompleted = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      userId: json['user_id'],
      role: json['role'] ?? 'shop_owner',
      shopName: json['shop_name'],
      ownerName: json['owner_name'],
      gstNumber: json['gst_number'],
      mobile: json['mobile'],
      email: json['email'],
      address: json['address'],
      city: json['city'],
      logoUrl: json['logo_url'],
      signatureUrl: json['signature_url'],
      isProfileCompleted: json['is_profile_completed'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role': role,
      'shop_name': shopName,
      'owner_name': ownerName,
      'gst_number': gstNumber,
      'mobile': mobile,
      'email': email,
      'address': address,
      'city': city,
      'logo_url': logoUrl,
      'signature_url': signatureUrl,
      'is_profile_completed': isProfileCompleted,
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Profile copyWith({
    String? shopName,
    String? ownerName,
    String? gstNumber,
    String? mobile,
    String? email,
    String? address,
    String? city,
    String? logoUrl,
    String? signatureUrl,
    bool? isProfileCompleted,
    bool? isActive,
  }) {
    return Profile(
      id: id,
      userId: userId,
      role: role,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      gstNumber: gstNumber ?? this.gstNumber,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      logoUrl: logoUrl ?? this.logoUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
