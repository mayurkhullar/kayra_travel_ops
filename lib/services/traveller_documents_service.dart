import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/traveller_document.dart';

class TravellerDocumentContext {
  const TravellerDocumentContext({
    required this.groupId,
    required this.groupType,
    required this.travellerId,
  });

  final String groupId;
  final String groupType;
  final String travellerId;
}

class TravellerDocumentsService {
  TravellerDocumentsService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get _travellers =>
      _firestore.collection('travellers');
  CollectionReference<Map<String, dynamic>> get _documents =>
      _firestore.collection('documents');

  Future<TravellerDocumentContext> resolveDocumentContext({
    required String accountUid,
    required String groupId,
  }) async {
    print('Traveller docs: current group id=$groupId');
    print('Traveller docs: current traveller uid=$accountUid');

    try {
      final groupSnapshot = await _groups.doc(groupId).get();
      if (!groupSnapshot.exists) {
        throw const TravellerDocumentsException(
          'Group context is missing. Please login again.',
        );
      }

      final groupData = groupSnapshot.data() ?? const <String, dynamic>{};
      final groupType = (groupData['groupType'] as String?)?.trim() ?? '';

      final travellerQuery = await _travellers
          .where('accountId', isEqualTo: accountUid)
          .where('groupId', isEqualTo: groupId)
          .get();

      if (travellerQuery.docs.isEmpty) {
        throw const TravellerDocumentsException(
          'Traveller record not found for this group. Please contact support.',
        );
      }

      final travellerDoc = _selectDeterministicTravellerDoc(travellerQuery.docs);
      print('Traveller docs: current traveller id=${travellerDoc.id}');

      return TravellerDocumentContext(
        groupId: groupId,
        groupType: groupType,
        travellerId: travellerDoc.id,
      );
    } on FirebaseException catch (error, stackTrace) {
      print('Traveller docs: caught exception message=${error.message ?? error.code}');
      print('Traveller docs: stack=${stackTrace.toString().split('\n').first}');
      throw TravellerDocumentsException(
        error.message ?? 'Unable to load traveller document context.',
      );
    } on TravellerDocumentsException {
      rethrow;
    } catch (error, stackTrace) {
      print('Traveller docs: caught exception message=$error');
      print('Traveller docs: stack=${stackTrace.toString().split('\n').first}');
      throw const TravellerDocumentsException(
        'Unable to load traveller document context.',
      );
    }
  }

  Future<Map<String, TravellerDocument>> loadLatestDocumentsByType({
    required String groupId,
    required String travellerId,
  }) async {
    try {
      final snapshot = await _documents
          .where('groupId', isEqualTo: groupId)
          .where('travellerId', isEqualTo: travellerId)
          .get();

      final latestByType = <String, TravellerDocument>{};

      for (final doc in snapshot.docs) {
        final parsed = TravellerDocument.fromFirestore(doc.id, doc.data());
        final current = latestByType[parsed.documentType];
        if (current == null || parsed.version > current.version) {
          latestByType[parsed.documentType] = parsed;
          continue;
        }

        if (current.isActive == false && parsed.isActive == true) {
          latestByType[parsed.documentType] = parsed;
        }
      }

      return latestByType;
    } on FirebaseException catch (error, stackTrace) {
      print('Traveller docs: caught exception message=${error.message ?? error.code}');
      print('Traveller docs: stack=${stackTrace.toString().split('\n').first}');
      throw TravellerDocumentsException(
        error.message ?? 'Unable to load document status.',
      );
    }
  }

  Future<void> uploadDocument({
    required String groupId,
    required String travellerId,
    required String documentType,
    required PlatformFile file,
  }) async {
    print('Traveller docs: document type selected type=$documentType');

    if ((groupId).trim().isEmpty) {
      throw const TravellerDocumentsException('Group context is missing.');
    }

    if ((travellerId).trim().isEmpty) {
      throw const TravellerDocumentsException('Traveller context is missing.');
    }

    if (file.bytes == null || file.bytes!.isEmpty) {
      throw const TravellerDocumentsException('No file selected for upload.');
    }

    try {
      final previousSnapshot = await _documents
          .where('groupId', isEqualTo: groupId)
          .where('travellerId', isEqualTo: travellerId)
          .where('documentType', isEqualTo: documentType)
          .get();

      final existingDocs = previousSnapshot.docs
          .map((doc) => TravellerDocument.fromFirestore(doc.id, doc.data()))
          .toList();

      final currentActiveDocs = existingDocs
          .where((doc) => doc.isActive)
          .toList();

      final maxVersion = existingDocs.isEmpty
          ? 0
          : existingDocs.map((doc) => doc.version).reduce((a, b) => a > b ? a : b);
      final nextVersion = maxVersion + 1;

      final extension = _resolveFileExtension(file);
      final storagePath =
          'groups/$groupId/travellers/$travellerId/documents/${documentType}_v$nextVersion$extension';

      print('Traveller docs: upload started path=$storagePath');

      final storageRef = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: _guessContentType(extension));

      await storageRef.putData(file.bytes!, metadata);

      print('Traveller docs: upload success with storage path=$storagePath');
      print('Traveller docs: metadata write started type=$documentType');

      final batch = _firestore.batch();

      for (final oldDoc in currentActiveDocs) {
        print('Traveller docs: old version superseded id=${oldDoc.id}');
        batch.update(_documents.doc(oldDoc.id), <String, dynamic>{
          'isActive': false,
          'status': TravellerDocumentStatus.superseded,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final newDocumentRef = _documents.doc();
      batch.set(newDocumentRef, <String, dynamic>{
        'id': newDocumentRef.id,
        'groupId': groupId,
        'travellerId': travellerId,
        'documentType': documentType,
        'storagePath': storagePath,
        'version': nextVersion,
        'isActive': true,
        'status': TravellerDocumentStatus.uploaded,
        'uploadedBy': 'traveller',
        'uploadedAt': FieldValue.serverTimestamp(),
        'reviewedBy': null,
        'reviewedAt': null,
      });

      await batch.commit();
      print('Traveller docs: metadata write success type=$documentType');
    } on FirebaseException catch (error, stackTrace) {
      print('Traveller docs: caught exception message=${error.message ?? error.code}');
      print('Traveller docs: stack=${stackTrace.toString().split('\n').first}');
      throw TravellerDocumentsException(
        error.message ?? 'Unable to upload document right now.',
      );
    } on TravellerDocumentsException {
      rethrow;
    } catch (error, stackTrace) {
      print('Traveller docs: caught exception message=$error');
      print('Traveller docs: stack=${stackTrace.toString().split('\n').first}');
      throw const TravellerDocumentsException(
        'Unable to upload document right now.',
      );
    }
  }

  List<String> requiredDocumentTypesForGroupType(String groupType) {
    final normalized = groupType.toLowerCase();
    if (normalized == 'domestic') {
      return TravellerDocumentType.domesticRequired;
    }

    return TravellerDocumentType.internationalRequired;
  }

  String _resolveFileExtension(PlatformFile file) {
    final explicit = (file.extension ?? '').trim();
    if (explicit.isNotEmpty) {
      return '.${explicit.toLowerCase()}';
    }

    final name = file.name;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < name.length - 1) {
      return '.${name.substring(dotIndex + 1).toLowerCase()}';
    }

    return '';
  }

  String? _guessContentType(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.pdf':
        return 'application/pdf';
      default:
        return null;
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

class TravellerDocumentsException implements Exception {
  const TravellerDocumentsException(this.message);

  final String message;

  @override
  String toString() => message;
}
