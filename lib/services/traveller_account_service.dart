import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/traveller_account.dart';
import '../models/traveller_group_context.dart';

class TravellerAccountLookupResult {
  const TravellerAccountLookupResult({
    required this.documentId,
    required this.data,
  });

  final String documentId;
  final Map<String, dynamic> data;

  TravellerAccount get account => TravellerAccount.fromFirestore(documentId, data);
}

class TravellerAccountService {
  TravellerAccountService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get _travellerAccounts =>
      _firestore.collection('traveller_accounts');

  Future<TravellerGroupContext> resolveGroupByCode(String routeGroupCode) async {
    final groupCode = routeGroupCode.trim();
    print('Traveller link stage: route group code received code=$groupCode');
    if (groupCode.isEmpty) {
      throw const TravellerAccountException('Group link not found.');
    }

    try {
      final query = await _groups
          .where('travellerLinkPath', isEqualTo: groupCode)
          .where('travellerLinkEnabled', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw const TravellerAccountException('Group link not found.');
      }

      final groupDoc = query.docs.first;
      final groupData = groupDoc.data();
      final context = TravellerGroupContext.fromFirestore(
        groupDoc.id,
        groupData,
        groupCode: groupCode,
      );
      print(
        'Traveller link stage: group resolved successfully groupId=${context.id} code=$groupCode',
      );
      return context;
    } on TravellerAccountException {
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      _printFirestoreError(
        stage: 'Traveller link stage',
        error: error,
        stackTrace: stackTrace,
      );
      throw TravellerAccountException(_mapFirestoreError(error));
    } catch (error, stackTrace) {
      _printGenericError(
        stage: 'Traveller link stage',
        error: error,
        stackTrace: stackTrace,
      );
      throw const TravellerAccountException(
        'Unable to open this traveller link right now.',
      );
    }
  }

  String normalizePhone(String input) => input.replaceAll(RegExp(r'\D'), '');

  String buildTravellerAuthEmail(String rawPhone) {
    final normalized = normalizePhone(rawPhone);
    if (normalized.isEmpty) {
      throw const TravellerAccountException('Enter a valid mobile number.');
    }
    return '$normalized@traveller.kayra.local';
  }

  Future<TravellerAccountLookupResult?> findByPhone(String phone) async {
    final rawPhone = phone.trim();
    final normalizedPhone = normalizePhone(phone);
    if (rawPhone.isEmpty && normalizedPhone.isEmpty) {
      return null;
    }

    try {
      print('First-time setup stage: phone lookup started phone=$normalizedPhone');
      Future<QuerySnapshot<Map<String, dynamic>>> queryByPhoneValue(
        String phoneValue,
      ) {
        return _travellerAccounts.where('phone', isEqualTo: phoneValue).limit(1).get();
      }

      var query = await queryByPhoneValue(normalizedPhone);
      if (query.docs.isEmpty && rawPhone.isNotEmpty && rawPhone != normalizedPhone) {
        query = await queryByPhoneValue(rawPhone);
      }

      if (query.docs.isEmpty) {
        return null;
      }

      final doc = query.docs.first;
      print(
        'First-time setup stage: traveller account found by phone docId=${doc.id}',
      );
      return TravellerAccountLookupResult(documentId: doc.id, data: doc.data());
    } on FirebaseException catch (error, stackTrace) {
      _printFirestoreError(
        stage: 'Traveller account phone lookup',
        error: error,
        stackTrace: stackTrace,
      );
      throw TravellerAccountException(_mapFirestoreError(error));
    }
  }

  Future<TravellerAccount?> getTravellerByUid(String uid) async {
    try {
      print('Existing login stage: UID-based traveller account lookup started uid=$uid');
      final doc = await _travellerAccounts.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      print('Existing login stage: traveller account found uid=$uid');
      return TravellerAccount.fromFirestore(doc.id, doc.data()!);
    } on FirebaseException catch (error, stackTrace) {
      _printFirestoreError(
        stage: 'Traveller account UID lookup',
        error: error,
        stackTrace: stackTrace,
      );
      throw TravellerAccountException(_mapFirestoreError(error));
    }
  }

  void validateAccountForGroup({
    required TravellerAccount account,
    required String groupId,
    required String stage,
  }) {
    if (!account.isActive) {
      throw const TravellerAccountException(
        'This traveller account is inactive. Please contact support.',
      );
    }

    if (!account.groupIds.contains(groupId)) {
      throw const TravellerAccountException(
        'This traveller account is not linked to this group.',
      );
    }

    print('$stage: group membership valid groupId=$groupId uid=${account.id}');
  }

  Future<void> upsertCanonicalTravellerAccount({
    required TravellerAccountLookupResult source,
    required String uid,
    required String authEmail,
  }) async {
    final sourceData = Map<String, dynamic>.from(source.data);
    final canonicalData = <String, dynamic>{
      ...sourceData,
      'authUid': uid,
      'authEmail': authEmail,
      'phone': normalizePhone((sourceData['phone'] as String?) ?? ''),
      'id': uid,
      'isActive': (sourceData['isActive'] as bool?) ?? true,
      'groupIds': sourceData['groupIds'] ?? <String>[],
      'passwordInitializedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final batch = _firestore.batch();
      final canonicalRef = _travellerAccounts.doc(uid);
      batch.set(canonicalRef, canonicalData, SetOptions(merge: true));

      if (source.documentId != uid) {
        batch.set(
          _travellerAccounts.doc(source.documentId),
          {
            'authUid': uid,
            'authEmail': authEmail,
            'migratedToUid': uid,
            'isCanonical': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      print(
        'First-time setup stage: UID-based traveller account write/update complete uid=$uid',
      );
    } on FirebaseException catch (error) {
      throw TravellerAccountException(_mapFirestoreError(error));
    }
  }

  void _printFirestoreError({
    required String stage,
    required FirebaseException error,
    required StackTrace stackTrace,
  }) {
    final firstStackLine = stackTrace.toString().split('\n').first;
    print('$stage: exception type=${error.runtimeType}');
    print('$stage: code=${error.code} message=${error.message ?? error.code}');
    print('$stage: stackTraceFirstLine=$firstStackLine');
  }

  void _printGenericError({
    required String stage,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final firstStackLine = stackTrace.toString().split('\n').first;
    print('$stage: exception type=${error.runtimeType}');
    print('$stage: message=$error');
    print('$stage: stackTraceFirstLine=$firstStackLine');
  }

  String _mapFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permission denied while loading traveller access.';
      case 'unavailable':
        return 'Network error while loading traveller data.';
      default:
        return error.message ?? 'Traveller data request failed.';
    }
  }
}

class TravellerAccountException implements Exception {
  const TravellerAccountException(this.message);

  final String message;

  @override
  String toString() => message;
}
