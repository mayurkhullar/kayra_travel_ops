import 'package:flutter/material.dart';

import '../../providers/traveller_auth_provider.dart';
import '../../utils/app_dialogs.dart';
import '../../widgets/app_loading_overlay.dart';
import '../../widgets/app_primary_button.dart';

class TravellerFirstTimeSetupScreen extends StatefulWidget {
  const TravellerFirstTimeSetupScreen({
    super.key,
    required this.authProvider,
  });

  final TravellerAuthProvider authProvider;

  @override
  State<TravellerFirstTimeSetupScreen> createState() =>
      _TravellerFirstTimeSetupScreenState();
}

class _TravellerFirstTimeSetupScreenState
    extends State<TravellerFirstTimeSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
        message: 'Please provide valid signup details.',
      );
      return;
    }

    await widget.authProvider.firstTimeSetup(
      mobile: _mobileController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (!mounted) {
      return;
    }

    if (widget.authProvider.isAuthenticated) {
      await AppDialogs.showSuccess(
        context,
        title: 'Signup complete',
        message: 'Your traveller account is ready.',
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      return;
    }

    await AppDialogs.showError(
      context,
      title: 'Signup failed',
      message:
          widget.authProvider.errorMessage ?? 'Unable to complete signup now.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authProvider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Traveller Sign up')),
          body: AppLoadingOverlay(
            isLoading: widget.authProvider.isLoading,
            message: 'Creating your account...',
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
                            decoration: const InputDecoration(
                              labelText: 'Create password',
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Confirm password',
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          AppPrimaryButton(
                            label: 'Sign up',
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
