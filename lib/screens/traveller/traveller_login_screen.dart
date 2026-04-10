import 'package:flutter/material.dart';

import '../../providers/traveller_auth_provider.dart';
import '../../utils/app_dialogs.dart';
import '../../widgets/app_loading_overlay.dart';
import '../../widgets/app_primary_button.dart';

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
    if (widget.authProvider.isLoading) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      await AppDialogs.showError(
        context,
        title: 'Validation error',
        message: 'Please provide mobile number and password.',
      );
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
      await AppDialogs.showSuccess(
        context,
        message: 'Login successful.',
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      return;
    }

    await AppDialogs.showError(
      context,
      title: 'Login failed',
      message: widget.authProvider.errorMessage ?? 'Unable to login right now.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authProvider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Traveller Login')),
          body: AppLoadingOverlay(
            isLoading: widget.authProvider.isLoading,
            message: 'Logging in...',
            child: SafeArea(
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
                            decoration:
                                const InputDecoration(labelText: 'Password'),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          AppPrimaryButton(
                            label: 'Login',
                            isLoading: widget.authProvider.isLoading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
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
