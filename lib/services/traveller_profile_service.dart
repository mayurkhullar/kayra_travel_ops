import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/traveller_profile.dart';

class TravellerProfileService {
  TravellerProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _travellers =>
      _firestore.collection('travellers');
  CollectionReference<Map<String, dynamic>> get _travellerAccounts =>
      _firestore.collection('traveller_accounts');

  Future<TravellerProfile> loadTravellerProfile({
    required String accountUid,
    required String groupId,
  }) async {
    print('Traveller profile: current traveller uid=$accountUid');
    print('Traveller profile: current group id=$groupId');
    print('Traveller profile: traveller record lookup start');

    try {
      final query = await _travellers
          .where('accountId', isEqualTo: accountUid)
          .where('groupId', isEqualTo: groupId)
          .get();

      if (query.docs.isEmpty) {
        print('Traveller profile: traveller record lookup failure (none found)');
        throw const TravellerProfileException(
          'No traveller record found for this group. Please contact support.',
        );
      }

      final selectedDoc = _selectDeterministicTravellerDoc(query.docs);
      final travellerData = selectedDoc.data();
      final accountDoc = await _travellerAccounts.doc(accountUid).get();
      final accountData = accountDoc.data() ?? const <String, dynamic>{};

      final merged = Map<String, dynamic>.from(travellerData);
      if ((merged['fullName'] as String?)?.trim().isEmpty ?? true) {
        merged['fullName'] = (accountData['fullName'] as String?)?.trim() ?? '';
      }
      if ((merged['email'] as String?)?.trim().isEmpty ?? true) {
        merged['email'] = (accountData['email'] as String?)?.trim() ?? '';
      }

      print('Traveller profile: traveller record lookup success docId=${selectedDoc.id}');
      return TravellerProfile.fromFirestore(selectedDoc.id, merged);
    } on FirebaseException catch (error, stackTrace) {
      print('Traveller profile: traveller record lookup failure code=${error.code}');
      print('Traveller profile: caught exception message=${error.message ?? error.code}');
      print('Traveller profile: stack=${stackTrace.toString().split('\n').first}');
      throw TravellerProfileException(
        error.message ?? 'Failed to load traveller profile.',
      );
    } on TravellerProfileException {
      rethrow;
    } catch (error, stackTrace) {
      print('Traveller profile: caught exception message=$error');
      print('Traveller profile: stack=${stackTrace.toString().split('\n').first}');
      throw const TravellerProfileException(
        'Failed to load traveller profile right now.',
      );
    }
  }

  Future<void> saveTravellerProfile(TravellerProfile profile) async {
    print('Traveller profile: save started docId=${profile.travellerDocId}');

    try {
      await _travellers
          .doc(profile.travellerDocId)
          .set(profile.toTravellerUpdateMap(), SetOptions(merge: true));

      await _travellerAccounts.doc(profile.accountId).set(
        <String, dynamic>{
          'fullName': profile.fullName.trim(),
          'email': profile.email.trim(),
          'profileCompleted': profile.profileCompleted,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      print('Traveller profile: save success docId=${profile.travellerDocId}');
    } on FirebaseException catch (error, stackTrace) {
      print('Traveller profile: caught exception message=${error.message ?? error.code}');
      print('Traveller profile: stack=${stackTrace.toString().split('\n').first}');
      throw TravellerProfileException(
        error.message ?? 'Unable to save traveller profile right now.',
      );
    } catch (error, stackTrace) {
      print('Traveller profile: caught exception message=$error');
      print('Traveller profile: stack=${stackTrace.toString().split('\n').first}');
      throw const TravellerProfileException(
        'Unable to save traveller profile right now.',
      );
    }
  }

  QueryDocumentSnapshot<Map<String, dynamic>> _selectDeterministicTravellerDoc(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = [...docs]
      ..sort((a, b) {
        DateTime? createdAtFromData(Map<String, dynamic> data) {
          final raw = data['createdAt'];
          if (raw is Timestamp) {
            return raw.toDate();
          }
          if (raw is DateTime) {
            return raw;
          }
          return null;
        }

        final aCreated = createdAtFromData(a.data());
        final bCreated = createdAtFromData(b.data());

        if (aCreated != null && bCreated != null) {
          final compareDates = aCreated.compareTo(bCreated);
          if (compareDates != 0) {
            return compareDates;
          }
        } else if (aCreated != null && bCreated == null) {
          return -1;
        } else if (aCreated == null && bCreated != null) {
          return 1;
        }

        return a.id.compareTo(b.id);
      });

    return sorted.first;
  }
}

class TravellerProfileException implements Exception {
  const TravellerProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}
