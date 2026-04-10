import 'package:flutter/material.dart';

import '../../../models/internal_traveller_review_item.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/internal_traveller_review_service.dart';

class TravellerReviewDetailScreen extends StatefulWidget {
  const TravellerReviewDetailScreen({
    super.key,
    required this.authProvider,
    required this.travellerId,
    InternalTravellerReviewService? reviewService,
  }) : _reviewService = reviewService;

  final AuthProvider authProvider;
  final String travellerId;
  final InternalTravellerReviewService? _reviewService;

  @override
  State<TravellerReviewDetailScreen> createState() =>
      _TravellerReviewDetailScreenState();
}

class _TravellerReviewDetailScreenState
    extends State<TravellerReviewDetailScreen> {
  late final InternalTravellerReviewService _reviewService;
  late Future<InternalTravellerReviewDetail> _detailFuture;
  bool _isSubmitting = false;

  bool get _canReview {
    final role = widget.authProvider.role;
    return role == 'manager' || role == 'super_admin';
  }

  @override
  void initState() {
    super.initState();
    _reviewService = widget._reviewService ?? InternalTravellerReviewService();
    _detailFuture = _loadDetail();
  }

  Future<InternalTravellerReviewDetail> _loadDetail() async {
    final detail = await _reviewService.loadReviewDetail(
      travellerId: widget.travellerId,
    );

    if (_canReview && detail.traveller.status == 'submitted') {
      await _reviewService.markUnderReviewIfSubmitted(
        travellerId: widget.travellerId,
      );
      return _reviewService.loadReviewDetail(travellerId: widget.travellerId);
    }

    return detail;
  }

  Future<void> _approve() async {
    if (!_canReview || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _reviewService.approveTraveller(
        travellerId: widget.travellerId,
        reviewerUid: widget.authProvider.currentUser?.id ?? '',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Traveller approved.')),
      );
      setState(() {
        _detailFuture = _reviewService.loadReviewDetail(
          travellerId: widget.travellerId,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to approve traveller: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _reject() async {
    if (!_canReview || _isSubmitting) {
      return;
    }

    final reasonController = TextEditingController();
    String? reviewReason;

    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject traveller'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                reviewReason = reasonController.text.trim();
                Navigator.of(context).pop(true);
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (shouldReject != true) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _reviewService.rejectTraveller(
        travellerId: widget.travellerId,
        reviewerUid: widget.authProvider.currentUser?.id ?? '',
        reviewReason: reviewReason,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Traveller rejected.')),
      );
      setState(() {
        _detailFuture = _reviewService.loadReviewDetail(
          travellerId: widget.travellerId,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to reject traveller: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveller Review Detail'),
      ),
      body: FutureBuilder<InternalTravellerReviewDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load traveller detail.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('Traveller detail not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionCard(
                context,
                title: 'Traveller',
                children: [
                  _row('Full name', detail.traveller.fullName),
                  _row('Phone', detail.traveller.phone),
                  _row('Email', detail.traveller.email),
                  _row('Date of birth', _formatDate(context, detail.dateOfBirth)),
                  _row('Gender', detail.gender),
                  _row('Status', detail.traveller.status),
                  _row('Passport number', detail.passportNumber),
                  _row('Passport country', detail.passportIssuingCountry),
                  _row(
                    'Passport expiry',
                    _formatDate(context, detail.passportExpiryDate),
                  ),
                  _row('Passport validity', detail.passportValidityStatus),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                context,
                title: 'Group',
                children: [
                  _row('Name', detail.group?.groupName),
                  _row('Destination', detail.group?.destination),
                  _row('Type', detail.group?.groupType),
                  _row('Start date', _formatDate(context, detail.group?.startDate)),
                  _row('End date', _formatDate(context, detail.group?.endDate)),
                ],
              ),
              const SizedBox(height: 12),
              _sectionCard(
                context,
                title: 'Documents',
                children: detail.documents.isEmpty
                    ? [
                        const Text('No active documents found.'),
                      ]
                    : detail.documents
                        .map(
                          (doc) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(doc.documentType),
                            subtitle: Text(
                              'Status: ${doc.status}\n'
                              'Version: ${doc.version}\n'
                              'Uploaded: ${_formatDate(context, doc.uploadedAt) ?? '-'}',
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 20),
              if (!_canReview)
                const Text(
                  'Read-only access. Only manager and super_admin can approve or reject.',
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _approve,
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _isSubmitting ? null : _reject,
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: ${(value ?? '').trim().isNotEmpty ? value : '-'}'),
    );
  }

  String? _formatDate(BuildContext context, DateTime? value) {
    if (value == null) {
      return null;
    }
    return MaterialLocalizations.of(context).formatMediumDate(value);
  }
}
