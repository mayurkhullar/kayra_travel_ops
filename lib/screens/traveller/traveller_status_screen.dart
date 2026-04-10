import 'package:flutter/material.dart';

import '../../providers/traveller_auth_provider.dart';
import '../../services/traveller_submission_service.dart';

class TravellerStatusScreen extends StatefulWidget {
  const TravellerStatusScreen({
    super.key,
    required this.authProvider,
  });

  final TravellerAuthProvider authProvider;

  @override
  State<TravellerStatusScreen> createState() => _TravellerStatusScreenState();
}

class _TravellerStatusScreenState extends State<TravellerStatusScreen> {
  final TravellerSubmissionService _submissionService =
      TravellerSubmissionService();

  bool _isLoading = true;
  String? _errorMessage;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
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
      final status = await _submissionService.loadCurrentStatus(
        accountUid: account.id,
        groupId: group.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
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
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load status right now.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submission Status')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Current Traveller Status',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              (_status ?? 'draft').toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(_statusDescription(_status ?? 'draft')),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _loadStatus,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh Status'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  String _statusDescription(String status) {
    switch (status) {
      case 'draft':
        return 'Your submission is still in progress.';
      case 'submitted':
      case 'under_review':
        return 'Your details are under review by our team.';
      case 'approved':
        return 'Your traveller details are approved.';
      case 'rejected':
        return 'Changes are required before approval.';
      case 'incomplete':
        return 'Complete missing profile and document details to submit.';
      case 'cancelled':
        return 'This submission has been cancelled.';
      default:
        return 'Status updated. Please check back later.';
    }
  }
}
