import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';

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
    return AnimatedBuilder(
      animation: _authProvider,
      builder: (context, _) {
        return MaterialApp(
          title: 'Kayra Holiday Maps',
          debugShowCheckedModeBanner: false,
          home: _AuthDebugScreen(authProvider: _authProvider),
        );
      },
    );
  }
}

class _AuthDebugScreen extends StatefulWidget {
  const _AuthDebugScreen({required this.authProvider});

  final AuthProvider authProvider;

  @override
  State<_AuthDebugScreen> createState() => _AuthDebugScreenState();
}

class _AuthDebugScreenState extends State<_AuthDebugScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authProvider;

    return Scaffold(
      appBar: AppBar(title: const Text('Auth Bootstrap Check')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: auth.isLoading
            ? const Center(child: CircularProgressIndicator())
            : auth.isAuthenticated
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('UID: ${auth.currentUser?.id ?? '-'}'),
                      Text('Email: ${auth.currentUser?.email ?? '-'}'),
                      Text('Role: ${auth.role ?? '-'}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => auth.signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      if (auth.errorMessage != null) ...[
                        Text(
                          auth.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await auth.signIn(
                              email: _emailController.text,
                              password: _passwordController.text,
                            );
                          } catch (_) {
                            // Error state is exposed through authProvider.errorMessage.
                          }
                        },
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
