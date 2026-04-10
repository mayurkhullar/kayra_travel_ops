import 'package:flutter/material.dart';

import '../../../models/internal_traveller_review_item.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/internal_traveller_review_service.dart';
import 'traveller_review_detail_screen.dart';

class TravellerReviewQueueScreen extends StatefulWidget {
  const TravellerReviewQueueScreen({
    super.key,
    required this.authProvider,
    InternalTravellerReviewService? reviewService,
  }) : _reviewService = reviewService;

  final AuthProvider authProvider;
  final InternalTravellerReviewService? _reviewService;

  @override
  State<TravellerReviewQueueScreen> createState() =>
      _TravellerReviewQueueScreenState();
}

class _TravellerReviewQueueScreenState extends State<TravellerReviewQueueScreen> {
  late final InternalTravellerReviewService _reviewService;
  late Future<List<InternalTravellerReviewItem>> _queueFuture;
  ReviewQueueFilter _selectedFilter = ReviewQueueFilter.submitted;

  @override
  void initState() {
    super.initState();
    _reviewService = widget._reviewService ?? InternalTravellerReviewService();

    final user = widget.authProvider.currentUser;
    print('Internal review queue: current staff uid=${user?.id ?? '-'} role=${user?.role ?? '-'}');

    _queueFuture = _loadQueue();
  }

  Future<List<InternalTravellerReviewItem>> _loadQueue() {
    return _reviewService.loadQueue(status: _selectedFilter.statusValue);
  }

  void _refresh() {
    setState(() {
      _queueFuture = _loadQueue();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveller Review Queue'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: ReviewQueueFilter.values
                  .map(
                    (filter) => ChoiceChip(
                      label: Text(filter.label),
                      selected: _selectedFilter == filter,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                          _queueFuture = _loadQueue();
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<InternalTravellerReviewItem>>(
              future: _queueFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Unable to load review queue.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? const <InternalTravellerReviewItem>[];
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No travellers found for ${_selectedFilter.label.toLowerCase()}.',
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final submittedDate = _formatDate(context, item.submittedAt);

                      return ListTile(
                        title: Text(item.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Group: ${item.groupName ?? '-'}'),
                            Text('Destination: ${item.destination ?? '-'}'),
                            Text('Status: ${item.status}'),
                            Text('Submitted: ${submittedDate ?? '-'}'),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TravellerReviewDetailScreen(
                                authProvider: widget.authProvider,
                                travellerId: item.travellerId,
                                reviewService: _reviewService,
                              ),
                            ),
                          );
                          _refresh();
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _formatDate(BuildContext context, DateTime? value) {
    if (value == null) {
      return null;
    }

    return MaterialLocalizations.of(context).formatMediumDate(value);
  }
}

enum ReviewQueueFilter {
  submitted('Submitted', 'submitted'),
  approved('Approved', 'approved'),
  rejected('Rejected', 'rejected');

  const ReviewQueueFilter(this.label, this.statusValue);

  final String label;
  final String statusValue;
}
