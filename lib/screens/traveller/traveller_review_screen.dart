import 'package:flutter/material.dart';

import '../../models/traveller_document.dart';
import '../../providers/traveller_auth_provider.dart';
import '../../services/traveller_submission_service.dart';
import '../../utils/app_dialogs.dart';
import '../../widgets/app_loading_overlay.dart';
import '../../widgets/app_primary_button.dart';
import 'traveller_status_screen.dart';

class TravellerReviewScreen extends StatefulWidget {
  const TravellerReviewScreen({
    super.key,
    required this.authProvider,
  });

  final TravellerAuthProvider authProvider;

  @override
  State<TravellerReviewScreen> createState() => _TravellerReviewScreenState();
}

class _TravellerReviewScreenState extends State<TravellerReviewScreen> {
  final TravellerSubmissionService _submissionService =
      TravellerSubmissionService();

  TravellerSubmissionSnapshot? _snapshot;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
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
      final snapshot = await _submissionService.loadSubmissionSnapshot(
        accountUid: account.id,
        groupId: group.id,
        groupType: group.groupType ?? '',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } on TravellerSubmissionException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      print('Traveller submission: caught exception message=$error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load review details right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForReview() async {
    final snapshot = _snapshot;
    if (snapshot == null || _isSubmitting) {
      return;
    }

    if (!snapshot.isComplete) {
      await AppDialogs.showError(
        context,
        title: 'Incomplete details',
        message:
            'Please complete all required profile fields and documents before submitting.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _submissionService.submitForReview(snapshot);

      if (!mounted) {
        return;
      }

      await AppDialogs.showSuccess(
        context,
        message: 'Your details were submitted for review.',
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TravellerStatusScreen(
            authProvider: widget.authProvider,
          ),
        ),
      );
    } on TravellerSubmissionException catch (error) {
      print('Traveller submission: caught exception message=${error.message}');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });

      await AppDialogs.showError(
        context,
        title: 'Submission blocked',
        message: error.message,
      );
    } catch (error) {
      print('Traveller submission: caught exception message=$error');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to submit details right now.';
        _isSubmitting = false;
      });
      await AppDialogs.showError(
        context,
        title: 'Submission failed',
        message: 'Unable to submit details right now.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review & Submit')),
      body: AppLoadingOverlay(
        isLoading: _isSubmitting,
        message: 'Submitting details...',
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null && _snapshot == null
                  ? _buildLoadErrorState()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return _buildLoadErrorState();
    }

    final profile = snapshot.profile;

    return RefreshIndicator(
      onRefresh: _loadReview,
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
                    'Profile Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('Full name: ${profile.fullName.isEmpty ? '-' : profile.fullName}'),
                  Text('Date of birth: ${_formatDate(profile.dateOfBirth)}'),
                  Text('Gender: ${(profile.gender ?? '').isEmpty ? '-' : profile.gender}'),
                  Text(
                    'Passport number: ${profile.passportNumber.isEmpty ? '-' : profile.passportNumber}',
                  ),
                  Text(
                    'Passport expiry: ${_formatDate(profile.passportExpiryDate)}',
                  ),
                  Text(
                    'Passport issuing country: ${profile.passportIssuingCountry.isEmpty ? '-' : profile.passportIssuingCountry}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Document Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...snapshot.requiredDocumentTypes.map((type) {
                    final document = snapshot.latestActiveDocumentsByType[type];
                    final status = document?.status ?? TravellerDocumentStatus.notUploaded;
                    final isPresent = document != null &&
                        document.isActive &&
                        document.status != TravellerDocumentStatus.superseded;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(TravellerDocumentType.label(type)),
                          ),
                          Text(isPresent ? 'Present' : 'Missing'),
                          const SizedBox(width: 8),
                          Text('(${TravellerDocumentStatus.label(status)})'),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: snapshot.isComplete
                ? Colors.green.withValues(alpha: 0.08)
                : Colors.orange.withValues(alpha: 0.10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.isComplete
                        ? 'Your details are complete.'
                        : 'Your details are incomplete.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (snapshot.missingItems.isEmpty)
                    const Text('No missing items.'),
                  ...snapshot.missingItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $item'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'Submit for Review',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submitForReview,
          ),
        ],
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
              _errorMessage ?? 'Unable to load submission details.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadReview,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }

    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
