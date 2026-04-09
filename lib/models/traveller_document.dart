import 'package:cloud_firestore/cloud_firestore.dart';

class TravellerDocumentType {
  static const String aadhaar = 'aadhaar';
  static const String pan = 'pan';
  static const String passportFront = 'passport_front';
  static const String passportBack = 'passport_back';

  static const List<String> domesticRequired = <String>[
    aadhaar,
    pan,
  ];

  static const List<String> internationalRequired = <String>[
    passportFront,
    passportBack,
    pan,
  ];

  static String label(String type) {
    switch (type) {
      case aadhaar:
        return 'Aadhaar';
      case pan:
        return 'PAN';
      case passportFront:
        return 'Passport Front';
      case passportBack:
        return 'Passport Back';
      default:
        return type;
    }
  }
}

class TravellerDocumentStatus {
  static const String notUploaded = 'not_uploaded';
  static const String uploaded = 'uploaded';
  static const String underReview = 'under_review';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String reuploadRequired = 'reupload_required';
  static const String superseded = 'superseded';

  static String label(String status) {
    switch (status) {
      case notUploaded:
        return 'Not uploaded';
      case uploaded:
        return 'Uploaded';
      case underReview:
        return 'Under review';
      case approved:
        return 'Approved';
      case rejected:
        return 'Rejected';
      case reuploadRequired:
        return 'Reupload required';
      case superseded:
        return 'Superseded';
      default:
        return status;
    }
  }
}

class TravellerDocument {
  const TravellerDocument({
    required this.id,
    required this.groupId,
    required this.travellerId,
    required this.documentType,
    required this.storagePath,
    required this.version,
    required this.isActive,
    required this.status,
    required this.uploadedBy,
    this.uploadedAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String id;
  final String groupId;
  final String travellerId;
  final String documentType;
  final String storagePath;
  final int version;
  final bool isActive;
  final String status;
  final String uploadedBy;
  final DateTime? uploadedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  factory TravellerDocument.fromFirestore(
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

    return TravellerDocument(
      id: (data['id'] as String?)?.trim().isNotEmpty == true
          ? (data['id'] as String).trim()
          : documentId,
      groupId: (data['groupId'] as String?)?.trim() ?? '',
      travellerId: (data['travellerId'] as String?)?.trim() ?? '',
      documentType: (data['documentType'] as String?)?.trim() ?? '',
      storagePath: (data['storagePath'] as String?)?.trim() ?? '',
      version: (data['version'] as num?)?.toInt() ?? 1,
      isActive: (data['isActive'] as bool?) ?? false,
      status: (data['status'] as String?)?.trim() ??
          TravellerDocumentStatus.notUploaded,
      uploadedBy: (data['uploadedBy'] as String?)?.trim() ?? 'traveller',
      uploadedAt: parseDate(data['uploadedAt']),
      reviewedBy: (data['reviewedBy'] as String?)?.trim(),
      reviewedAt: parseDate(data['reviewedAt']),
    );
  }
}
