import 'package:flutter/material.dart';

import '../../providers/traveller_auth_provider.dart';
import '../../utils/app_dialogs.dart';

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
                                final shouldLogout =
                                    await AppDialogs.showConfirmation(
                                  context,
                                  title: 'Logout',
                                  message: 'Are you sure you want to logout?',
                                  confirmText: 'Logout',
                                  isDestructive: true,
                                );
                                if (!shouldLogout) {
                                  return;
                                }
                                await authProvider.logout();
                                if (!context.mounted) {
                                  return;
                                }
                                if (authProvider.errorMessage != null) {
                                  await AppDialogs.showError(
                                    context,
                                    title: 'Logout failed',
                                    message: authProvider.errorMessage!,
                                  );
                                }
                              },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
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
}
