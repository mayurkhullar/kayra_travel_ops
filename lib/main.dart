import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/home/bootstrap_home_screen.dart';
import 'screens/traveller/traveller_link_bootstrap_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider()..initialize();
  }

  @override
  void dispose() {
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final travellerGroupCode = _extractTravellerGroupCode(Uri.base);

    return AnimatedBuilder(
      animation: _authProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'Kayra Travel Ops',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF102A43),
              primary: const Color(0xFF102A43),
              secondary: const Color(0xFFF0B429),
            ),
            useMaterial3: true,
          ),
          home: travellerGroupCode != null
              ? TravellerLinkBootstrapScreen(groupCode: travellerGroupCode)
              : BootstrapHomeScreen(authProvider: _authProvider),
        );
      },
    );
  }

  String? _extractTravellerGroupCode(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'g') {
      final code = segments[1].trim();
      if (code.isNotEmpty) {
        return code;
      }
    }
    return null;
  }
}
