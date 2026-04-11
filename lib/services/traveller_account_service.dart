import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/traveller_account.dart';
import '../models/traveller_group_context.dart';
import 'traveller_identity_mapper.dart';

class TravellerAccountService {
  TravellerAccountService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get _travellerAccounts =>
      _firestore.collection('traveller_accounts');
  CollectionReference<Map<String, dynamic>> get _travellers =>
      _firestore.collection('travellers');

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

  String normalizePhone(String input) => sanitizeTravellerPhone(input);

  String buildTravellerAuthEmail(String rawPhone) =>
      mapTravellerPhoneToAuthEmail(rawPhone);

  Future<void> createTravellerAccountAndInitialTraveller({
    required String uid,
    required String phone,
    required TravellerGroupContext group,
  }) async {
    final now = FieldValue.serverTimestamp();
    final passportValidityStatus = group.isDomestic ? 'not_applicable' : 'valid';

    final travellerAccountData = <String, dynamic>{
      'id': uid,
      'authUid': uid,
      'fullName': '',
      'phone': phone,
      'email': '',
      'isActive': true,
      'groupIds': [group.id],
      'createdAt': now,
    };

    final travellerData = <String, dynamic>{
      'accountId': uid,
      'groupId': group.id,
      'travellerType': 'primary',
      'linkedPrimaryTravellerId': null,
      'fullName': '',
      'phone': phone,
      'email': '',
      'status': 'draft',
      'passportValidityStatus': passportValidityStatus,
      'roomAssignmentId': null,
      'flightAssignmentIds': <String>[],
      'createdAt': now,
    };

    try {
      print('Signup stage: traveller_accounts doc write started uid=$uid');
      final batch = _firestore.batch();
      batch.set(_travellerAccounts.doc(uid), travellerAccountData);

      print('Signup stage: travellers doc create started uid=$uid groupId=${group.id}');
      batch.set(_travellers.doc(), travellerData);

      await batch.commit();
      print('Signup stage: traveller_accounts doc write success uid=$uid');
      print('Signup stage: travellers doc create success uid=$uid groupId=${group.id}');
    } on FirebaseException catch (error, stackTrace) {
      _printFirestoreError(
        stage: 'Signup stage',
        error: error,
        stackTrace: stackTrace,
      );
      throw TravellerAccountException(
        'Could not finish signup while saving traveller profile. Please try again.',
      );
    }
  }

  Future<TravellerAccount?> getTravellerByUid(String uid) async {
    try {
      print('traveller_accounts doc lookup started uid=$uid');
      final doc = await _travellerAccounts.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        print('traveller_accounts doc missing uid=$uid');
        return null;
      }
      print('traveller_accounts doc found uid=$uid');
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

  Future<QuerySnapshot<Map<String, dynamic>>> getTravellerRecordsForGroup({
    required String uid,
    required String groupId,
  }) async {
    try {
      return await _travellers
          .where('accountId', isEqualTo: uid)
          .where('groupId', isEqualTo: groupId)
          .limit(1)
          .get();
    } on FirebaseException catch (error, stackTrace) {
      _printFirestoreError(
        stage: 'Traveller access traveller record lookup',
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
        'This account is not linked to this group.',
      );
    }

    print('$stage: group membership valid groupId=$groupId uid=${account.id}');
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
