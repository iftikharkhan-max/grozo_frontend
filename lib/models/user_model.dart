class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? cnic;
  final String? mobile;
  final String? address;
  final String language;
  final bool notifyOrders;
  final bool notifyPromotions;

  UserModel({
    required this.id, required this.name, required this.email,
    required this.role, this.cnic, this.mobile, this.address,
    this.language = 'en', this.notifyOrders = true, this.notifyPromotions = true,
  });

  bool get isCustomer => role == 'Customer';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      cnic: json['cnic'],
      mobile: json['mobile'],
      address: json['address'],
      language: json['language'] ?? 'en',
      notifyOrders: json['notify_orders'] != false,
      notifyPromotions: json['notify_promotions'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'cnic': cnic,
        'mobile': mobile,
        'address': address,
        'language': language,
        'notify_orders': notifyOrders,
        'notify_promotions': notifyPromotions,
      };
}
