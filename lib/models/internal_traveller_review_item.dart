import 'package:cloud_firestore/cloud_firestore.dart';

class InternalTravellerReviewItem {
  const InternalTravellerReviewItem({
    required this.travellerId,
    required this.accountId,
    required this.groupId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.status,
    this.submittedAt,
    this.groupName,
    this.destination,
  });

  final String travellerId;
  final String accountId;
  final String groupId;
  final String fullName;
  final String phone;
  final String email;
  final String status;
  final DateTime? submittedAt;
  final String? groupName;
  final String? destination;

  factory InternalTravellerReviewItem.fromTravellerDoc(
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

    return InternalTravellerReviewItem(
      travellerId: documentId,
      accountId: (data['accountId'] as String?)?.trim() ?? '',
      groupId: (data['groupId'] as String?)?.trim() ?? '',
      fullName: (data['fullName'] as String?)?.trim() ?? '-',
      phone: (data['phone'] as String?)?.trim() ?? '-',
      email: (data['email'] as String?)?.trim() ?? '-',
      status: (data['status'] as String?)?.trim() ?? 'draft',
      submittedAt: parseDate(data['submittedAt']) ?? parseDate(data['createdAt']),
    );
  }

  InternalTravellerReviewItem copyWith({
    String? groupName,
    String? destination,
  }) {
    return InternalTravellerReviewItem(
      travellerId: travellerId,
      accountId: accountId,
      groupId: groupId,
      fullName: fullName,
      phone: phone,
      email: email,
      status: status,
      submittedAt: submittedAt,
      groupName: groupName ?? this.groupName,
      destination: destination ?? this.destination,
    );
  }
}

class InternalTravellerGroupSummary {
  const InternalTravellerGroupSummary({
    required this.groupId,
    required this.groupName,
    this.destination,
    this.groupType,
    this.startDate,
    this.endDate,
  });

  final String groupId;
  final String groupName;
  final String? destination;
  final String? groupType;
  final DateTime? startDate;
  final DateTime? endDate;
}

class InternalTravellerDocumentSummary {
  const InternalTravellerDocumentSummary({
    required this.id,
    required this.documentType,
    required this.status,
    required this.version,
    this.uploadedAt,
  });

  final String id;
  final String documentType;
  final String status;
  final int version;
  final DateTime? uploadedAt;
}

class InternalTravellerReviewDetail {
  const InternalTravellerReviewDetail({
    required this.traveller,
    required this.group,
    required this.documents,
    this.dateOfBirth,
    this.gender,
    this.passportNumber,
    this.passportIssuingCountry,
    this.passportExpiryDate,
    this.passportValidityStatus,
  });

  final InternalTravellerReviewItem traveller;
  final InternalTravellerGroupSummary? group;
  final List<InternalTravellerDocumentSummary> documents;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? passportNumber;
  final String? passportIssuingCountry;
  final DateTime? passportExpiryDate;
  final String? passportValidityStatus;
}
