import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/traveller_account.dart';
import '../models/traveller_group_context.dart';

class TravellerAccountService {
  TravellerAccountService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get _travellerAccounts =>
      _firestore.collection('traveller_accounts');

  String normalizePhone(String input) => input.replaceAll(RegExp(r'\D'), '');

  String buildTravellerAuthEmail(String rawPhone) {
    final normalized = normalizePhone(rawPhone);
    return 'traveller.$normalized@traveller.kayra.app';
  }

  Future<TravellerGroupContext> resolveGroupByCode(String routeGroupCode) async {
    final groupCode = routeGroupCode.trim();
    if (groupCode.isEmpty) {
      throw const TravellerAccountException('Group link not found.');
    }

    try {
      print('Group code: $groupCode');
      final query = await _groups
          .where('travellerLinkPath', isEqualTo: groupCode)
          .where('travellerLinkEnabled', isEqualTo: true)
          .limit(1)
          .get();
      print('Docs found: ${query.docs.length}');

      if (query.docs.isEmpty) {
        throw const TravellerAccountException('Group link not found.');
      }

      final groupDoc = query.docs.first;
      final groupData = groupDoc.data();
      final groupId = groupDoc.id;

      final context = TravellerGroupContext.fromFirestore(
        groupId,
        groupData,
        groupCode: groupCode,
      );

      return context;
    } on TravellerAccountException {
      rethrow;
    } on FirebaseException catch (error) {
      throw TravellerAccountException(_mapFirestoreError(error));
    } catch (_) {
      throw const TravellerAccountException(
        'Unable to open this traveller link right now.',
      );
    }
  }

  Future<TravellerAccount> getTravellerByPhoneForGroup({
    required String phone,
    required String groupId,
  }) async {
    try {
      final account = await findByPhone(phone);
      if (account == null) {
        throw const TravellerAccountException('Mobile number not found.');
      }
      validateAccountForGroup(account: account, groupId: groupId);
      return account;
    } on TravellerAccountException {
      rethrow;
    } on FirebaseException catch (error) {
      throw TravellerAccountException(_mapFirestoreError(error));
    } catch (_) {
      throw const TravellerAccountException(
        'Unable to load traveller account. Please try again.',
      );
    }
  }

  Future<TravellerAccount?> findByPhone(String phone) async {
    final normalizedPhone = phone.trim();
    if (normalizedPhone.isEmpty) {
      return null;
    }

    try {
      final query = await _travellerAccounts
          .where('phone', isEqualTo: normalizedPhone)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        return null;
      }
      final doc = query.docs.first;
      return TravellerAccount.fromFirestore(doc.id, doc.data());
    } on FirebaseException catch (error) {
      throw TravellerAccountException(_mapFirestoreError(error));
    }
  }

  void validateAccountForGroup({
    required TravellerAccount account,
    required String groupId,
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
  }

  Future<TravellerAccount?> getTravellerByAuthUid(String uid) async {
    try {
      final byUid =
          await _travellerAccounts.where('authUid', isEqualTo: uid).limit(1).get();
      if (byUid.docs.isNotEmpty) {
        final doc = byUid.docs.first;
        return TravellerAccount.fromFirestore(doc.id, doc.data());
      }
      return null;
    } on FirebaseException catch (error) {
      throw TravellerAccountException(_mapFirestoreError(error));
    }
  }

  Future<void> attachAuthToTravellerAccount({
    required String travellerId,
    required String authUid,
    required String authEmail,
  }) async {
    try {
      await _travellerAccounts.doc(travellerId).set(
        {
          'authUid': authUid,
          'authEmail': authEmail,
          'passwordInitializedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      throw TravellerAccountException(_mapFirestoreError(error));
    }
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
