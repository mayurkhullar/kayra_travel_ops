import 'package:cloud_firestore/cloud_firestore.dart';

class TravellerProfile {
  const TravellerProfile({
    required this.travellerDocId,
    required this.accountId,
    required this.groupId,
    required this.fullName,
    required this.email,
    this.dateOfBirth,
    this.gender,
    required this.passportNumber,
    this.passportExpiryDate,
    required this.passportIssuingCountry,
    required this.profileCompleted,
    this.status,
    this.passportValidityStatus,
    this.createdAt,
  });

  final String travellerDocId;
  final String accountId;
  final String groupId;
  final String fullName;
  final String email;
  final DateTime? dateOfBirth;
  final String? gender;
  final String passportNumber;
  final DateTime? passportExpiryDate;
  final String passportIssuingCountry;
  final bool profileCompleted;
  final String? status;
  final String? passportValidityStatus;
  final DateTime? createdAt;

  TravellerProfile copyWith({
    String? fullName,
    String? email,
    DateTime? dateOfBirth,
    String? gender,
    String? passportNumber,
    DateTime? passportExpiryDate,
    String? passportIssuingCountry,
    bool? profileCompleted,
    String? status,
    String? passportValidityStatus,
    DateTime? createdAt,
  }) {
    return TravellerProfile(
      travellerDocId: travellerDocId,
      accountId: accountId,
      groupId: groupId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      passportNumber: passportNumber ?? this.passportNumber,
      passportExpiryDate: passportExpiryDate ?? this.passportExpiryDate,
      passportIssuingCountry:
          passportIssuingCountry ?? this.passportIssuingCountry,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      status: status ?? this.status,
      passportValidityStatus: passportValidityStatus ?? this.passportValidityStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TravellerProfile.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    return TravellerProfile(
      travellerDocId: documentId,
      accountId: (data['accountId'] as String?)?.trim() ?? '',
      groupId: (data['groupId'] as String?)?.trim() ?? '',
      fullName: (data['fullName'] as String?)?.trim() ?? '',
      email: (data['email'] as String?)?.trim() ?? '',
      dateOfBirth: parseDate(data['dateOfBirth']),
      gender: (data['gender'] as String?)?.trim(),
      passportNumber: (data['passportNumber'] as String?)?.trim() ?? '',
      passportExpiryDate: parseDate(data['passportExpiryDate']),
      passportIssuingCountry:
          (data['passportIssuingCountry'] as String?)?.trim() ?? '',
      profileCompleted: (data['profileCompleted'] as bool?) ?? false,
      status: (data['status'] as String?)?.trim(),
      passportValidityStatus: (data['passportValidityStatus'] as String?)?.trim(),
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toTravellerUpdateMap() {
    return <String, dynamic>{
      'fullName': fullName.trim(),
      'email': email.trim(),
      'dateOfBirth':
          dateOfBirth == null ? null : Timestamp.fromDate(_stripTime(dateOfBirth!)),
      'gender': (gender ?? '').trim(),
      'passportNumber': passportNumber.trim(),
      'passportExpiryDate': passportExpiryDate == null
          ? null
          : Timestamp.fromDate(_stripTime(passportExpiryDate!)),
      'passportIssuingCountry': passportIssuingCountry.trim(),
      'status': status ?? 'draft',
      'passportValidityStatus': passportValidityStatus ?? 'valid',
      'profileCompleted': profileCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime _stripTime(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
