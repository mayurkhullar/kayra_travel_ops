import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserService {
  UserService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Future<AppUser> fetchOrCreateUser({
    required String uid,
    required String email,
  }) async {
    try {
      final existing = await _fetchByUidOrMappedId(uid);
      if (existing != null) {
        return existing;
      }

      final created = AppUser(
        id: uid,
        email: email,
        role: 'agent',
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _usersCollection.doc(uid).set(created.toMap(), SetOptions(merge: true));

      return created;
    } on FirebaseException catch (error) {
      throw UserException(_mapFirestoreError(error));
    } catch (_) {
      throw const UserException(
        'Unable to load your profile right now. Please try again.',
      );
    }
  }

  Future<AppUser?> _fetchByUidOrMappedId(String uid) async {
    final byUid = await _usersCollection.doc(uid).get();
    if (byUid.exists && byUid.data() != null) {
      final payload = byUid.data()!;
      final payloadId = payload['id'];
      if (payloadId is! String || payloadId.isEmpty) {
        payload['id'] = uid;
      }
      return AppUser.fromFirestore(payload);
    }

    final byMappedId = await _usersCollection.where('id', isEqualTo: uid).limit(1).get();
    if (byMappedId.docs.isNotEmpty) {
      return AppUser.fromFirestore(byMappedId.docs.first.data());
    }

    return null;
  }

  String _mapFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
        return 'Network error while loading profile. Please try again.';
      case 'permission-denied':
        return 'You do not have permission to access this profile.';
      default:
        return error.message ?? 'Failed to load user profile.';
    }
  }
}

class UserException implements Exception {
  const UserException(this.message);

  final String message;

  @override
  String toString() => message;
}
