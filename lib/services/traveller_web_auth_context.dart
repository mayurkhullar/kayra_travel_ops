import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

const String _travellerWebAppName = 'traveller-web-auth-app';

FirebaseAuth? _cachedTravellerAuth;

Future<FirebaseAuth> resolveTravellerAuthInstance() async {
  if (!kIsWeb) {
    return FirebaseAuth.instance;
  }

  if (_cachedTravellerAuth != null) {
    return _cachedTravellerAuth!;
  }

  FirebaseApp? travellerApp;
  for (final app in Firebase.apps) {
    if (app.name == _travellerWebAppName) {
      travellerApp = app;
      break;
    }
  }

  travellerApp ??= await Firebase.initializeApp(
    name: _travellerWebAppName,
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final auth = FirebaseAuth.instanceFor(app: travellerApp);
  await auth.setPersistence(Persistence.SESSION);

  _cachedTravellerAuth = auth;
  return auth;
}
