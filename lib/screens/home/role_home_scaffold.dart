import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';
import '../../utils/app_dialogs.dart';

class RoleHomeScaffold extends StatelessWidget {
  const RoleHomeScaffold({
    super.key,
    required this.title,
    required this.roleLabel,
    required this.authProvider,
    this.quickActions = const <Widget>[],
  });

  final String title;
  final String roleLabel;
  final AuthProvider authProvider;
  final List<Widget> quickActions;

  @override
  Widget build(BuildContext context) {
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF102A43),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: $roleLabel', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Name: ${user?.name?.isNotEmpty == true ? user!.name : '-'}'),
            Text('Email: ${user?.email ?? '-'}'),
            if (quickActions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...quickActions,
            ],
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () async {
                final shouldLogout = await AppDialogs.showConfirmation(
                  context,
                  title: 'Logout',
                  message: 'Are you sure you want to logout?',
                  confirmText: 'Logout',
                  isDestructive: true,
                );

                if (!shouldLogout) {
                  return;
                }

                try {
                  await authProvider.signOut();
                } catch (_) {
                  if (!context.mounted) {
                    return;
                  }
                  await AppDialogs.showError(
                    context,
                    title: 'Logout failed',
                    message: authProvider.errorMessage ?? 'Unable to logout right now.',
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
