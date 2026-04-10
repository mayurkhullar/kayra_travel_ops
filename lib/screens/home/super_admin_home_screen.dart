import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';
import '../internal/review/traveller_review_queue_screen.dart';
import 'role_home_scaffold.dart';

class SuperAdminHomeScreen extends StatelessWidget {
  const SuperAdminHomeScreen({super.key, required this.authProvider});

  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      title: 'Kayra Travel Ops',
      roleLabel: 'super_admin',
      authProvider: authProvider,
      quickActions: [
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TravellerReviewQueueScreen(
                  authProvider: authProvider,
                ),
              ),
            );
          },
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Traveller Review Queue'),
        ),
      ],
    );
  }
}
