enum UserRole {
  customer,
  driver,
  admin,
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
    };
  }

  static String _resolveDisplayName(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? json['full_name'] ?? '').toString().trim();
    if (rawName.isNotEmpty && rawName.toLowerCase() != 'new user') {
      return rawName;
    }
    final email = (json['email'] ?? '').toString().trim();
    if (email.contains('@')) {
      final local = email.split('@').first;
      final parts = local
          .split(RegExp(r'[._\-]+'))
          .where((p) => p.isNotEmpty)
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .toList();
      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    }
    return rawName.isNotEmpty ? rawName : 'Registered Customer';
  }

  // Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] ?? 'customer').toString().trim();
    final parsedRole = UserRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => UserRole.customer,
    );
    return UserModel(
      id: (json['id'] ?? '').toString(),
      name: _resolveDisplayName(json),
      email: (json['email'] ?? '').toString(),
      role: parsedRole,
    );
  }

  // Helper to get role displayName
  String get roleDisplayName {
    switch (role) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.driver:
        return 'Driver';
      case UserRole.admin:
        return 'Administrator';
    }
  }
}
