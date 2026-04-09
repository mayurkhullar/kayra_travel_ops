import 'package:cloud_firestore/cloud_firestore.dart';

class TravellerGroupContext {
  const TravellerGroupContext({
    required this.id,
    required this.groupCode,
    required this.groupName,
    this.destination,
    this.startDate,
    this.endDate,
    required this.travellerLinkPath,
    required this.travellerLinkEnabled,
  });

  final String id;
  final String groupCode;
  final String groupName;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String travellerLinkPath;
  final bool travellerLinkEnabled;

  factory TravellerGroupContext.fromFirestore(
    String documentId,
    Map<String, dynamic> data, {
    required String groupCode,
  }) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    return TravellerGroupContext(
      id: documentId,
      groupCode: groupCode,
      groupName: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Travel Group',
      destination: (data['destination'] as String?)?.trim(),
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      travellerLinkPath: (data['travellerLinkPath'] as String?)?.trim() ??
          '/g/$groupCode',
      travellerLinkEnabled: (data['travellerLinkEnabled'] as bool?) ?? false,
    );
  }
}
