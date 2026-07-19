class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? cnic;
  final String? mobile;
  final String? address;

  UserModel({
    required this.id, required this.name, required this.email,
    required this.role, this.cnic, this.mobile, this.address,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      cnic: json['cnic'],
      mobile: json['mobile'],
      address: json['address'],
    );
  }
}