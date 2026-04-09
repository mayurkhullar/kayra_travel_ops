import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';
import 'role_home_scaffold.dart';

class AgentHomeScreen extends StatelessWidget {
  const AgentHomeScreen({super.key, required this.authProvider});

  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      title: 'Kayra Travel Ops',
      roleLabel: 'agent',
      authProvider: authProvider,
    );
  }
}
