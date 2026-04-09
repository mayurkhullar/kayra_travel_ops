import 'package:flutter/material.dart';

import '../../providers/auth_provider.dart';
import '../auth/auth_loading_screen.dart';
import '../auth/login_screen.dart';
import 'agent_home_screen.dart';
import 'manager_home_screen.dart';
import 'super_admin_home_screen.dart';
import 'team_leader_home_screen.dart';

class BootstrapHomeScreen extends StatelessWidget {
  const BootstrapHomeScreen({super.key, required this.authProvider});

  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    if (authProvider.isLoading) {
      return const AuthLoadingScreen();
    }

    if (!authProvider.isAuthenticated) {
      return LoginScreen(authProvider: authProvider);
    }

    switch (authProvider.role) {
      case 'super_admin':
        return SuperAdminHomeScreen(authProvider: authProvider);
      case 'manager':
        return ManagerHomeScreen(authProvider: authProvider);
      case 'team_leader':
        return TeamLeaderHomeScreen(authProvider: authProvider);
      case 'agent':
        return AgentHomeScreen(authProvider: authProvider);
      default:
        return LoginScreen(authProvider: authProvider);
    }
  }
}
