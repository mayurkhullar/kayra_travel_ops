import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';
import 'role_home_scaffold.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key, required this.authProvider});

  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    return RoleHomeScaffold(
      title: 'Kayra Travel Ops',
      roleLabel: 'manager',
      authProvider: authProvider,
    );
  }
}
