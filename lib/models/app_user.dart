import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String? name;
  final String email;
  final String role;
  final String? phone;
  final bool isActive;
  final DateTime? createdAt;

  factory AppUser.fromFirestore(Map<String, dynamic> data) {
    final createdAtValue = data['createdAt'];

    return AppUser(
      id: (data['id'] as String?) ?? '',
      name: data['name'] as String?,
      email: (data['email'] as String?) ?? '',
      role: (data['role'] as String?) ?? 'agent',
      phone: data['phone'] as String?,
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : createdAtValue is DateTime
              ? createdAtValue
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    };
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
