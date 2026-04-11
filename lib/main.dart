import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/home/bootstrap_home_screen.dart';
import 'screens/traveller/traveller_link_bootstrap_screen.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        appLog(
          'GlobalError',
          'FlutterError: ${details.exceptionAsString()}',
        );
        if (details.stack != null) {
          appLog('GlobalError', 'FlutterError STACK: ${details.stack}');
        }
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        appLogError('GlobalError', 'PlatformDispatcher.onError', error, stack);
        return false;
      };

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      runApp(const MyApp());
    },
    (error, stackTrace) {
      appLogError('GlobalError', 'runZonedGuarded', error, stackTrace);
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AuthProvider? _authProvider;
  late final String? _travellerGroupCode;

  @override
  void initState() {
    super.initState();
    _travellerGroupCode = _extractTravellerGroupCode(Uri.base);

    if (_travellerGroupCode == null) {
      _authProvider = AuthProvider()..initialize();
    }
  }

  @override
  void dispose() {
    _authProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_travellerGroupCode != null) {
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
        home: TravellerLinkBootstrapScreen(groupCode: _travellerGroupCode),
      );
    }

    return AnimatedBuilder(
      animation: _authProvider!,
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
          home: BootstrapHomeScreen(authProvider: _authProvider!),
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
