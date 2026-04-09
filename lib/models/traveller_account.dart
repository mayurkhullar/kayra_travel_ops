import 'package:cloud_firestore/cloud_firestore.dart';

class TravellerAccount {
  const TravellerAccount({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    required this.isActive,
    required this.groupIds,
    this.authUid,
    this.authEmail,
    this.createdAt,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final bool isActive;
  final List<String> groupIds;
  final String? authUid;
  final String? authEmail;
  final DateTime? createdAt;

  bool get isInitialized =>
      (authUid != null && authUid!.isNotEmpty) ||
      (authEmail != null && authEmail!.isNotEmpty);

  factory TravellerAccount.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final createdAtValue = data['createdAt'];
    final groups = data['groupIds'];

    return TravellerAccount(
      id: (data['id'] as String?)?.trim().isNotEmpty == true
          ? (data['id'] as String).trim()
          : documentId,
      fullName: (data['fullName'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim(),
      email: (data['email'] as String?)?.trim(),
      isActive: (data['isActive'] as bool?) ?? true,
      groupIds: groups is List
          ? groups.whereType<String>().map((item) => item.trim()).toList()
          : const <String>[],
      authUid: (data['authUid'] as String?)?.trim(),
      authEmail: (data['authEmail'] as String?)?.trim(),
      createdAt: createdAtValue is Timestamp
          ? createdAtValue.toDate()
          : createdAtValue is DateTime
              ? createdAtValue
              : null,
    );
  }
}
