import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';

class RoleHomeScaffold extends StatelessWidget {
  const RoleHomeScaffold({
    super.key,
    required this.title,
    required this.roleLabel,
    required this.authProvider,
  });

  final String title;
  final String roleLabel;
  final AuthProvider authProvider;

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
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () async {
                try {
                  await authProvider.signOut();
                } catch (_) {
                  // Signout failures are surfaced in auth provider error state.
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
