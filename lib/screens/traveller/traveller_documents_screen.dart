import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/traveller_document.dart';
import '../../providers/traveller_auth_provider.dart';
import '../../services/traveller_documents_service.dart';
import '../../utils/app_dialogs.dart';
import '../../widgets/app_loading_overlay.dart';
import '../../widgets/app_primary_button.dart';
import 'traveller_review_screen.dart';

class TravellerDocumentsScreen extends StatefulWidget {
  const TravellerDocumentsScreen({
    super.key,
    required this.authProvider,
  });

  final TravellerAuthProvider authProvider;

  @override
  State<TravellerDocumentsScreen> createState() => _TravellerDocumentsScreenState();
}

class _TravellerDocumentsScreenState extends State<TravellerDocumentsScreen> {
  final TravellerDocumentsService _documentsService = TravellerDocumentsService();

  TravellerDocumentContext? _context;
  List<String> _requiredDocumentTypes = const <String>[];
  Map<String, TravellerDocument> _latestDocuments =
      const <String, TravellerDocument>{};

  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _uploadingTypes = <String>{};

  bool get _isUploadingAny => _uploadingTypes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadDocumentsState();
  }

  Future<void> _loadDocumentsState() async {
    final account = widget.authProvider.currentTravellerAccount;
    final group = widget.authProvider.currentGroup;

    if (account == null || group == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Missing traveller or group context. Please login again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final contextData = await _documentsService.resolveDocumentContext(
        accountUid: account.id,
        groupId: group.id,
      );

      final required = _documentsService.requiredDocumentTypesForGroupType(
        contextData.groupType,
      );

      final latest = await _documentsService.loadLatestDocumentsByType(
        groupId: contextData.groupId,
        travellerAuthUid: contextData.travellerAuthUid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _context = contextData;
        _requiredDocumentTypes = required;
        _latestDocuments = latest;
        _isLoading = false;
      });
    } on TravellerDocumentsException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      print('Traveller docs: caught exception message=$error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load document status right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndUpload(String documentType) async {
    if (_uploadingTypes.contains(documentType)) {
      return;
    }

    final contextData = _context;
    if (contextData == null) {
      setState(() {
        _errorMessage = 'Missing traveller document context.';
      });
      await AppDialogs.showError(
        context,
        message: 'Missing traveller document context. Please retry.',
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null || result.files.isEmpty) {
      if (!mounted) {
        return;
      }
      await AppDialogs.showInfo(
        context,
        title: 'No file selected',
        message: 'Please select a file to upload.',
      );
      return;
    }

    final selected = result.files.first;
    if (selected.bytes == null || selected.bytes!.isEmpty) {
      if (!mounted) {
        return;
      }
      await AppDialogs.showError(
        context,
        title: 'Invalid file',
        message: 'Selected file is empty.',
      );
      return;
    }

    setState(() {
      _uploadingTypes.add(documentType);
      _errorMessage = null;
    });

    try {
      await _documentsService.uploadDocument(
        groupId: contextData.groupId,
        travellerAuthUid: contextData.travellerAuthUid,
        documentType: documentType,
        file: selected,
      );

      if (!mounted) {
        return;
      }

      await AppDialogs.showSuccess(
        context,
        message: '${TravellerDocumentType.label(documentType)} uploaded.',
      );

      await _loadDocumentsState();
    } on TravellerDocumentsException catch (error) {
      print('Traveller docs: caught exception message=${error.message}');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
      await AppDialogs.showError(
        context,
        title: 'Upload failed',
        message: error.message,
      );
    } catch (error) {
      print('Traveller docs: caught exception message=$error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Upload failed. Please try again.';
      });
      await AppDialogs.showError(
        context,
        title: 'Upload failed',
        message: 'Upload failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingTypes.remove(documentType);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traveller Documents')),
      body: AppLoadingOverlay(
        isLoading: _isUploadingAny,
        message: 'Uploading document...',
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && _context == null
                  ? _buildLoadErrorState()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final contextData = _context;
    if (contextData == null) {
      return _buildLoadErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadDocumentsState,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Required Documents',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('Group ID: ${contextData.groupId}'),
                  Text('Traveller UID: ${contextData.travellerAuthUid}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_latestDocuments.isEmpty) ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No documents uploaded yet.'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ..._requiredDocumentTypes.map(_buildDocumentCard),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isUploadingAny
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TravellerReviewScreen(
                          authProvider: widget.authProvider,
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.checklist),
            label: const Text('Review & Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(String documentType) {
    final document = _latestDocuments[documentType];
    final status = document?.status ?? TravellerDocumentStatus.notUploaded;
    final isUploading = _uploadingTypes.contains(documentType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TravellerDocumentType.label(documentType),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('Status: ${TravellerDocumentStatus.label(status)}'),
                  if (document != null) ...[
                    const SizedBox(height: 2),
                    Text('Version: v${document.version}'),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: AppPrimaryButton(
                label: 'Upload',
                isLoading: isUploading,
                onPressed: isUploading ? null : () => _pickAndUpload(documentType),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load traveller documents.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadDocumentsState,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
