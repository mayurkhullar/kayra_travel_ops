import 'package:flutter/material.dart';

import '../../providers/traveller_auth_provider.dart';
import 'traveller_entry_screen.dart';

class TravellerLinkBootstrapScreen extends StatefulWidget {
  const TravellerLinkBootstrapScreen({
    super.key,
    required this.groupCode,
  });

  final String groupCode;

  @override
  State<TravellerLinkBootstrapScreen> createState() =>
      _TravellerLinkBootstrapScreenState();
}

class _TravellerLinkBootstrapScreenState extends State<TravellerLinkBootstrapScreen> {
  late final TravellerAuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = TravellerAuthProvider();
  }

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TravellerEntryScreen(
      authProvider: _authProvider,
      groupCode: widget.groupCode,
    );
  }
}
