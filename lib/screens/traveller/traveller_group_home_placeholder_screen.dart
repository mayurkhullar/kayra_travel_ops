import 'package:flutter/material.dart';

import '../../providers/traveller_auth_provider.dart';

class TravellerGroupHomePlaceholderScreen extends StatelessWidget {
  const TravellerGroupHomePlaceholderScreen({
    super.key,
    required this.authProvider,
  });

  final TravellerAuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    final traveller = authProvider.currentTravellerAccount;
    final group = authProvider.currentGroup;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveller Group Home'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome ${traveller?.fullName ?? 'Traveller'}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text('Group: ${group?.groupName ?? '-'}'),
                      Text('Destination: ${group?.destination ?? '-'}'),
                      Text('Group code: ${group?.groupCode ?? '-'}'),
                      Text('Group ID: ${group?.id ?? '-'}'),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: authProvider.isLoading
                            ? null
                            : () async {
                                await authProvider.logout();
                              },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                      ),
                      if (authProvider.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          authProvider.errorMessage!,
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
  }
}
