import 'package:flutter/material.dart';

import '../../providers/traveller_auth_provider.dart';

class TravellerLoginScreen extends StatefulWidget {
  const TravellerLoginScreen({super.key, required this.authProvider});

  final TravellerAuthProvider authProvider;

  @override
  State<TravellerLoginScreen> createState() => _TravellerLoginScreenState();
}

class _TravellerLoginScreenState extends State<TravellerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await widget.authProvider.login(
      mobile: _mobileController.text,
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (widget.authProvider.isAuthenticated) {
      print('Traveller login: final navigation starting destination=previous_screen');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authProvider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Traveller Login')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _mobileController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile number',
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(labelText: 'Password'),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: widget.authProvider.isLoading ? null : _submit,
                          child: widget.authProvider.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Login'),
                        ),
                        if (widget.authProvider.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.authProvider.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
