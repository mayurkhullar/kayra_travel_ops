import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/internal_traveller_review_item.dart';

class InternalTravellerReviewService {
  InternalTravellerReviewService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _travellers =>
      _firestore.collection('travellers');
  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get _documents =>
      _firestore.collection('documents');

  Future<List<InternalTravellerReviewItem>> loadQueue({
    required String status,
  }) async {
    print('Internal review queue: query start status=$status');

    try {
      final snapshot = await _travellers.where('status', isEqualTo: status).get();

      final items = snapshot.docs
          .map(
            (doc) => InternalTravellerReviewItem.fromTravellerDoc(
              doc.id,
              doc.data(),
            ),
          )
          .toList();

      final enriched = await _enrichWithGroupMeta(items);
      print('Internal review queue: query success count=${enriched.length}');
      return enriched;
    } on FirebaseException catch (error, stackTrace) {
      print('Internal review queue: caught exception message=${error.message ?? error.code}');
      print(
        'Internal review queue: stack=${stackTrace.toString().split('\n').first}',
      );
      throw InternalTravellerReviewException(
        error.message ?? 'Unable to load traveller review queue.',
      );
    } catch (error, stackTrace) {
      print('Internal review queue: caught exception message=$error');
      print(
        'Internal review queue: stack=${stackTrace.toString().split('\n').first}',
      );
      throw const InternalTravellerReviewException(
        'Unable to load traveller review queue.',
      );
    }
  }

  Future<InternalTravellerReviewDetail> loadReviewDetail({
    required String travellerId,
  }) async {
    print('Internal review detail: load start travellerId=$travellerId');

    try {
      final travellerDoc = await _travellers.doc(travellerId).get();
      if (!travellerDoc.exists) {
        throw const InternalTravellerReviewException(
          'Traveller record was not found.',
        );
      }

      final travellerData = travellerDoc.data() ?? const <String, dynamic>{};
      final traveller = InternalTravellerReviewItem.fromTravellerDoc(
        travellerDoc.id,
        travellerData,
      );

      final groupSummary = await _loadGroupSummary(traveller.groupId);
      final documents = await _loadActiveDocuments(
        groupId: traveller.groupId,
        travellerId: traveller.travellerId,
        accountId: traveller.accountId,
      );

      DateTime? parseDate(dynamic value) {
        if (value is Timestamp) {
          return value.toDate();
        }
        if (value is DateTime) {
          return value;
        }
        return null;
      }

      final detail = InternalTravellerReviewDetail(
        traveller: traveller.copyWith(
          groupName: groupSummary?.groupName,
          destination: groupSummary?.destination,
        ),
        group: groupSummary,
        documents: documents,
        dateOfBirth: parseDate(travellerData['dateOfBirth']),
        gender: (travellerData['gender'] as String?)?.trim(),
        passportNumber: (travellerData['passportNumber'] as String?)?.trim(),
        passportIssuingCountry:
            (travellerData['passportIssuingCountry'] as String?)?.trim(),
        passportExpiryDate: parseDate(travellerData['passportExpiryDate']),
        passportValidityStatus:
            (travellerData['passportValidityStatus'] as String?)?.trim(),
      );

      print('Internal review detail: load success travellerId=$travellerId');
      return detail;
    } on InternalTravellerReviewException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      print('Internal review detail: caught exception message=${error.message ?? error.code}');
      print(
        'Internal review detail: stack=${stackTrace.toString().split('\n').first}',
      );
      throw InternalTravellerReviewException(
        error.message ?? 'Unable to load traveller review detail.',
      );
    } catch (error, stackTrace) {
      print('Internal review detail: caught exception message=$error');
      print(
        'Internal review detail: stack=${stackTrace.toString().split('\n').first}',
      );
      throw const InternalTravellerReviewException(
        'Unable to load traveller review detail.',
      );
    }
  }

  Future<void> markUnderReviewIfSubmitted({
    required String travellerId,
  }) async {
    final travellerDoc = await _travellers.doc(travellerId).get();
    if (!travellerDoc.exists) {
      return;
    }

    final data = travellerDoc.data() ?? const <String, dynamic>{};
    final status = (data['status'] as String?)?.trim() ?? '';
    if (status != 'submitted') {
      return;
    }

    await _travellers.doc(travellerId).set(
      <String, dynamic>{
        'status': 'under_review',
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> approveTraveller({
    required String travellerId,
    required String reviewerUid,
  }) async {
    print('Internal review action: approve started travellerId=$travellerId reviewer=$reviewerUid');
    try {
      await _travellers.doc(travellerId).set(
        <String, dynamic>{
          'status': 'approved',
          'reviewedBy': reviewerUid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      print('Internal review action: approve success travellerId=$travellerId');
    } on FirebaseException catch (error, stackTrace) {
      print('Internal review action: caught exception message=${error.message ?? error.code}');
      print(
        'Internal review action: stack=${stackTrace.toString().split('\n').first}',
      );
      throw InternalTravellerReviewException(
        error.message ?? 'Unable to approve traveller right now.',
      );
    } catch (error, stackTrace) {
      print('Internal review action: caught exception message=$error');
      print(
        'Internal review action: stack=${stackTrace.toString().split('\n').first}',
      );
      throw const InternalTravellerReviewException(
        'Unable to approve traveller right now.',
      );
    }
  }

  Future<void> rejectTraveller({
    required String travellerId,
    required String reviewerUid,
    String? reviewReason,
  }) async {
    print('Internal review action: reject started travellerId=$travellerId reviewer=$reviewerUid');

    try {
      await _travellers.doc(travellerId).set(
        <String, dynamic>{
          'status': 'rejected',
          'reviewedBy': reviewerUid,
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewReason': (reviewReason ?? '').trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      print('Internal review action: reject success travellerId=$travellerId');
    } on FirebaseException catch (error, stackTrace) {
      print('Internal review action: caught exception message=${error.message ?? error.code}');
      print(
        'Internal review action: stack=${stackTrace.toString().split('\n').first}',
      );
      throw InternalTravellerReviewException(
        error.message ?? 'Unable to reject traveller right now.',
      );
    } catch (error, stackTrace) {
      print('Internal review action: caught exception message=$error');
      print(
        'Internal review action: stack=${stackTrace.toString().split('\n').first}',
      );
      throw const InternalTravellerReviewException(
        'Unable to reject traveller right now.',
      );
    }
  }

  Future<InternalTravellerGroupSummary?> _loadGroupSummary(String groupId) async {
    if (groupId.trim().isEmpty) {
      return null;
    }

    final groupDoc = await _groups.doc(groupId).get();
    if (!groupDoc.exists) {
      return null;
    }

    final data = groupDoc.data() ?? const <String, dynamic>{};

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    return InternalTravellerGroupSummary(
      groupId: groupId,
      groupName: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Travel Group',
      destination: (data['destination'] as String?)?.trim(),
      groupType: (data['groupType'] as String?)?.trim(),
      startDate: parseDate(data['departureDate']) ?? parseDate(data['startDate']),
      endDate: parseDate(data['arrivalDate']) ?? parseDate(data['endDate']),
    );
  }

  Future<List<InternalTravellerDocumentSummary>> _loadActiveDocuments({
    required String groupId,
    required String travellerId,
    required String accountId,
  }) async {
    final byTravellerId = await _documents
        .where('groupId', isEqualTo: groupId)
        .where('travellerId', isEqualTo: travellerId)
        .where('isActive', isEqualTo: true)
        .get();

    QuerySnapshot<Map<String, dynamic>>? byAccountId;
    if (byTravellerId.docs.isEmpty && accountId.trim().isNotEmpty && accountId != travellerId) {
      byAccountId = await _documents
          .where('groupId', isEqualTo: groupId)
          .where('travellerId', isEqualTo: accountId)
          .where('isActive', isEqualTo: true)
          .get();
    }

    final combinedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
      ...byTravellerId.docs,
      ...?byAccountId?.docs,
    ];

    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      return null;
    }

    final latestByType = <String, InternalTravellerDocumentSummary>{};
    for (final doc in combinedDocs) {
      final data = doc.data();
      final documentType = (data['documentType'] as String?)?.trim() ?? '';
      if (documentType.isEmpty) {
        continue;
      }

      final status = (data['status'] as String?)?.trim() ?? 'not_uploaded';
      if (status == 'superseded') {
        continue;
      }

      final parsed = InternalTravellerDocumentSummary(
        id: doc.id,
        documentType: documentType,
        status: status,
        version: (data['version'] as num?)?.toInt() ?? 1,
        uploadedAt: parseDate(data['uploadedAt']),
      );

      final current = latestByType[documentType];
      if (current == null || parsed.version > current.version) {
        latestByType[documentType] = parsed;
      }
    }

    final result = latestByType.values.toList()
      ..sort((a, b) => a.documentType.compareTo(b.documentType));
    return result;
  }

  Future<List<InternalTravellerReviewItem>> _enrichWithGroupMeta(
    List<InternalTravellerReviewItem> items,
  ) async {
    final groupIds = items.map((item) => item.groupId).where((id) => id.isNotEmpty).toSet();
    if (groupIds.isEmpty) {
      return items;
    }

    final summaries = <String, InternalTravellerGroupSummary>{};
    for (final groupId in groupIds) {
      final summary = await _loadGroupSummary(groupId);
      if (summary != null) {
        summaries[groupId] = summary;
      }
    }

    return items
        .map(
          (item) => item.copyWith(
            groupName: summaries[item.groupId]?.groupName,
            destination: summaries[item.groupId]?.destination,
          ),
        )
        .toList();
  }
}

class InternalTravellerReviewException implements Exception {
  const InternalTravellerReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}
