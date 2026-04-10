import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/traveller_document.dart';
import '../models/traveller_profile.dart';
import 'traveller_documents_service.dart';
import 'traveller_profile_service.dart';

class TravellerSubmissionSnapshot {
  const TravellerSubmissionSnapshot({
    required this.travellerDocId,
    required this.groupId,
    required this.accountUid,
    required this.groupType,
    required this.profile,
    required this.latestActiveDocumentsByType,
    required this.requiredDocumentTypes,
    required this.isProfileComplete,
    required this.isDocumentsComplete,
    required this.missingItems,
  });

  final String travellerDocId;
  final String groupId;
  final String accountUid;
  final String groupType;
  final TravellerProfile profile;
  final Map<String, TravellerDocument> latestActiveDocumentsByType;
  final List<String> requiredDocumentTypes;
  final bool isProfileComplete;
  final bool isDocumentsComplete;
  final List<String> missingItems;

  bool get isComplete => isProfileComplete && isDocumentsComplete;
}

class TravellerSubmissionService {
  TravellerSubmissionService({
    FirebaseFirestore? firestore,
    TravellerProfileService? profileService,
    TravellerDocumentsService? documentsService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _profileService = profileService ?? TravellerProfileService(),
        _documentsService = documentsService ?? TravellerDocumentsService();

  final FirebaseFirestore _firestore;
  final TravellerProfileService _profileService;
  final TravellerDocumentsService _documentsService;

  CollectionReference<Map<String, dynamic>> get _travellers =>
      _firestore.collection('travellers');

  Future<TravellerSubmissionSnapshot> loadSubmissionSnapshot({
    required String accountUid,
    required String groupId,
    required String groupType,
  }) async {
    print('Traveller submission: current traveller uid=$accountUid');
    print('Traveller submission: current group id=$groupId');

    try {
      final profile = await _profileService.loadTravellerProfile(
        accountUid: accountUid,
        groupId: groupId,
      );

      print(
        'Traveller submission: current traveller record id=${profile.travellerDocId}',
      );

      final latestActiveDocumentsByType =
          await _documentsService.loadLatestActiveDocumentsByType(
        groupId: groupId,
        travellerAuthUid: accountUid,
      );

      final requiredDocumentTypes =
          _documentsService.requiredDocumentTypesForGroupType(groupType);

      final missingItems = <String>[];

      if (profile.fullName.trim().isEmpty) {
        missingItems.add('Full name');
      }
      if (profile.dateOfBirth == null) {
        missingItems.add('Date of birth');
      }
      if ((profile.gender ?? '').trim().isEmpty) {
        missingItems.add('Gender');
      }
      if (profile.passportNumber.trim().isEmpty) {
        missingItems.add('Passport number');
      }
      if (profile.passportExpiryDate == null) {
        missingItems.add('Passport expiry');
      }
      if (profile.passportIssuingCountry.trim().isEmpty) {
        missingItems.add('Passport issuing country');
      }

      final documentMissing = <String>[];
      for (final documentType in requiredDocumentTypes) {
        final matching = latestActiveDocumentsByType[documentType];
        final isPresent = matching != null &&
            matching.isActive &&
            matching.status != TravellerDocumentStatus.superseded;
        if (!isPresent) {
          documentMissing.add(TravellerDocumentType.label(documentType));
        }
      }

      if (documentMissing.isNotEmpty) {
        missingItems.addAll(documentMissing.map((item) => 'Document: $item'));
      }

      final isProfileComplete = !missingItems.any(
        (item) => !item.startsWith('Document:'),
      );
      final isDocumentsComplete = documentMissing.isEmpty;

      print('Traveller submission: profile completeness result=$isProfileComplete');
      print(
        'Traveller submission: document completeness result=$isDocumentsComplete',
      );
      print('Traveller submission: missing items list=$missingItems');

      return TravellerSubmissionSnapshot(
        travellerDocId: profile.travellerDocId,
        groupId: groupId,
        accountUid: accountUid,
        groupType: groupType,
        profile: profile,
        latestActiveDocumentsByType: latestActiveDocumentsByType,
        requiredDocumentTypes: requiredDocumentTypes,
        isProfileComplete: isProfileComplete,
        isDocumentsComplete: isDocumentsComplete,
        missingItems: missingItems,
      );
    } on FirebaseException catch (error, stackTrace) {
      print('Traveller submission: caught exception message=${error.message ?? error.code}');
      print('Traveller submission: stack=${stackTrace.toString().split('\n').first}');
      throw TravellerSubmissionException(
        error.message ?? 'Unable to load submission details.',
      );
    } on TravellerProfileException catch (error, stackTrace) {
      print('Traveller submission: caught exception message=${error.message}');
      print('Traveller submission: stack=${stackTrace.toString().split('\n').first}');
      throw TravellerSubmissionException(error.message);
    } on TravellerDocumentsException catch (error, stackTrace) {
      print('Traveller submission: caught exception message=${error.message}');
      print('Traveller submission: stack=${stackTrace.toString().split('\n').first}');
      throw TravellerSubmissionException(error.message);
    } catch (error, stackTrace) {
      print('Traveller submission: caught exception message=$error');
      print('Traveller submission: stack=${stackTrace.toString().split('\n').first}');
      throw const TravellerSubmissionException(
        'Unable to load submission details right now.',
      );
    }
  }

  Future<String> submitForReview(TravellerSubmissionSnapshot snapshot) async {
    print('Traveller submission: submit started');

    if (!snapshot.isComplete) {
      await _markTravellerIncomplete(
        travellerDocId: snapshot.travellerDocId,
      );
      throw const TravellerSubmissionException(
        'Your profile is incomplete. Please complete all required fields and documents before submitting.',
      );
    }

    try {
      await _travellers.doc(snapshot.travellerDocId).set(
        <String, dynamic>{
          'status': 'submitted',
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      print('Traveller submission: submit success');
      return 'submitted';
    } on FirebaseException catch (error, stackTrace) {
      print('Traveller submission: caught exception message=${error.message ?? error.code}');
      print('Traveller submission: stack=${stackTrace.toString().split('\n').first}');
      throw TravellerSubmissionException(
        error.message ?? 'Unable to submit details for review.',
      );
    } catch (error, stackTrace) {
      print('Traveller submission: caught exception message=$error');
      print('Traveller submission: stack=${stackTrace.toString().split('\n').first}');
      throw const TravellerSubmissionException(
        'Unable to submit details for review.',
      );
    }
  }

  Future<String> loadCurrentStatus({
    required String accountUid,
    required String groupId,
  }) async {
    final profile = await _profileService.loadTravellerProfile(
      accountUid: accountUid,
      groupId: groupId,
    );
    return (profile.status ?? '').trim().isEmpty ? 'draft' : profile.status!.trim();
  }

  Future<void> _markTravellerIncomplete({
    required String travellerDocId,
  }) async {
    try {
      await _travellers.doc(travellerDocId).set(
        <String, dynamic>{
          'status': 'incomplete',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // best-effort status update
    }
  }
}

class TravellerSubmissionException implements Exception {
  const TravellerSubmissionException(this.message);

  final String message;

  @override
  String toString() => message;
}
