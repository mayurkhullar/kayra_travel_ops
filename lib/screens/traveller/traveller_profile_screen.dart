import 'package:flutter/material.dart';

import '../../models/traveller_profile.dart';
import '../../providers/traveller_auth_provider.dart';
import '../../services/traveller_profile_service.dart';

class TravellerProfileScreen extends StatefulWidget {
  const TravellerProfileScreen({
    super.key,
    required this.authProvider,
  });

  final TravellerAuthProvider authProvider;

  @override
  State<TravellerProfileScreen> createState() => _TravellerProfileScreenState();
}

class _TravellerProfileScreenState extends State<TravellerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _passportCountryController = TextEditingController();

  final TravellerProfileService _profileService = TravellerProfileService();

  TravellerProfile? _loadedProfile;
  DateTime? _dateOfBirth;
  DateTime? _passportExpiryDate;
  String? _gender;
  String? _errorMessage;
  String? _dateOfBirthError;
  String? _passportExpiryError;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passportNumberController.dispose();
    _passportCountryController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final account = widget.authProvider.currentTravellerAccount;
    final group = widget.authProvider.currentGroup;

    if (account == null || group == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Missing traveller or group context. Please login again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _profileService.loadTravellerProfile(
        accountUid: account.id,
        groupId: group.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadedProfile = profile;
        _fullNameController.text = profile.fullName;
        _emailController.text = profile.email;
        _passportNumberController.text = profile.passportNumber;
        _passportCountryController.text = profile.passportIssuingCountry;
        _dateOfBirth = profile.dateOfBirth;
        _passportExpiryDate = profile.passportExpiryDate;
        _gender = (profile.gender ?? '').trim().isEmpty ? null : profile.gender;
        _isLoading = false;
      });
    } on TravellerProfileException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load profile right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: _dateOfBirth ?? DateTime(now.year - 20),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dateOfBirth = DateTime(picked.year, picked.month, picked.day);
      _dateOfBirthError = null;
    });
  }

  Future<void> _pickPassportExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 30),
      initialDate: _passportExpiryDate ?? DateTime(now.year + 1),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _passportExpiryDate = DateTime(picked.year, picked.month, picked.day);
      _passportExpiryError = null;
    });
  }

  Future<void> _saveProfile() async {
    final profile = _loadedProfile;
    if (profile == null || _isSaving) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _dateOfBirthError = null;
      _passportExpiryError = null;
    });

    final isFormValid = _formKey.currentState?.validate() ?? false;
    var hasDateValidationError = false;

    if (_dateOfBirth == null) {
      hasDateValidationError = true;
      _dateOfBirthError = 'Date of birth is required.';
      print('Traveller profile: validation failure reason=dateOfBirth missing');
    }

    if (_passportExpiryDate == null) {
      hasDateValidationError = true;
      _passportExpiryError = 'Passport expiry date is required.';
      print('Traveller profile: validation failure reason=passportExpiry missing');
    } else {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      if (!_passportExpiryDate!.isAfter(todayDate)) {
        hasDateValidationError = true;
        _passportExpiryError = 'Passport expiry must be a future date.';
        print(
          'Traveller profile: validation failure reason=passportExpiry not future',
        );
      }
    }

    if (!isFormValid || hasDateValidationError) {
      setState(() {});
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedProfile = profile.copyWith(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        passportNumber: _passportNumberController.text.trim(),
        passportExpiryDate: _passportExpiryDate,
        passportIssuingCountry: _passportCountryController.text.trim(),
        profileCompleted: true,
      );

      await _profileService.saveTravellerProfile(updatedProfile);

      if (!mounted) {
        return;
      }

      setState(() {
        _loadedProfile = updatedProfile;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully.')),
      );
    } on TravellerProfileException catch (error, stackTrace) {
      print('Traveller profile: caught exception message=${error.message}');
      print('Traveller profile: stack=${stackTrace.toString().split('\n').first}');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isSaving = false;
      });
    } catch (error, stackTrace) {
      print('Traveller profile: caught exception message=$error');
      print('Traveller profile: stack=${stackTrace.toString().split('\n').first}');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to save profile right now.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.authProvider.currentGroup;
    final traveller = widget.authProvider.currentTravellerAccount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traveller Profile'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _loadedProfile == null
                ? _buildLoadErrorState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Group Context',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Group: ${group?.groupName ?? '-'}'),
                                      Text('Group ID: ${group?.id ?? '-'}'),
                                      Text(
                                        'Traveller UID: ${traveller?.id ?? '-'}',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildPersonalDetailsSection(context),
                              const SizedBox(height: 12),
                              _buildPassportSection(context),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                child: Text(
                                  _isSaving ? 'Saving...' : 'Save Profile',
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : () async {
                                        await widget.authProvider.logout();
                                      },
                                icon: const Icon(Icons.logout),
                                label: const Text('Logout'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildPersonalDetailsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Personal Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  print('Traveller profile: validation failure reason=fullName empty');
                  return 'Full name is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
                DropdownMenuItem(
                  value: 'prefer_not_to_say',
                  child: Text('Prefer not to say'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _gender = value;
                });
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDateOfBirth,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date of birth',
                  errorText: _dateOfBirthError,
                ),
                child: Text(
                  _formatDate(_dateOfBirth),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassportSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Passport Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passportNumberController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Passport number'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  print(
                    'Traveller profile: validation failure reason=passportNumber empty',
                  );
                  return 'Passport number is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickPassportExpiryDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Passport expiry date',
                  errorText: _passportExpiryError,
                ),
                child: Text(
                  _formatDate(_passportExpiryDate),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passportCountryController,
              textInputAction: TextInputAction.done,
              decoration:
                  const InputDecoration(labelText: 'Passport issuing country'),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  print(
                    'Traveller profile: validation failure reason=passportCountry empty',
                  );
                  return 'Passport issuing country is required.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to load traveller profile.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Select date';
    }

    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
