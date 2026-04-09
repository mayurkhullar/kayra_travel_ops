import 'package:flutter/material.dart';

import '../../providers/traveller_auth_provider.dart';
import 'traveller_first_time_setup_screen.dart';
import 'traveller_group_home_placeholder_screen.dart';
import 'traveller_login_screen.dart';

class TravellerEntryScreen extends StatefulWidget {
  const TravellerEntryScreen({
    super.key,
    required this.authProvider,
    required this.groupCode,
  });

  final TravellerAuthProvider authProvider;
  final String groupCode;

  @override
  State<TravellerEntryScreen> createState() => _TravellerEntryScreenState();
}

class _TravellerEntryScreenState extends State<TravellerEntryScreen> {
  @override
  void initState() {
    super.initState();
    widget.authProvider.initializeFromGroupLink(widget.groupCode);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authProvider,
      builder: (context, _) {
        final group = widget.authProvider.currentGroup;
        final account = widget.authProvider.currentTravellerAccount;

        if (widget.authProvider.isLoading && group == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (group == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_off, size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to open traveller link',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.authProvider.errorMessage ??
                          'This group link is missing or disabled.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (account != null) {
          return TravellerGroupHomePlaceholderScreen(
            authProvider: widget.authProvider,
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome to ${group.groupName}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          if ((group.destination ?? '').isNotEmpty)
                            Text(
                              'Destination: ${group.destination}',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _dateRange(group.startDate, group.endDate),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TravellerFirstTimeSetupScreen(
                                    authProvider: widget.authProvider,
                                  ),
                                ),
                              );
                            },
                            child: const Text('First-time setup'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => TravellerLoginScreen(
                                    authProvider: widget.authProvider,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Existing traveller login'),
                          ),
                          if (widget.authProvider.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              widget.authProvider.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _dateRange(DateTime? start, DateTime? end) {
    String format(DateTime? value) {
      if (value == null) {
        return 'TBD';
      }
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    }

    return 'Dates: ${format(start)} → ${format(end)}';
  }
}
