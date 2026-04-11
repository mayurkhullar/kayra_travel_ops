import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/traveller_account.dart';
import '../models/traveller_group_context.dart';
import '../services/traveller_account_service.dart';
import '../services/traveller_auth_service.dart';
import '../services/traveller_identity_mapper.dart';

class TravellerAuthProvider extends ChangeNotifier {
  TravellerAuthProvider({
    TravellerAuthService? authService,
    TravellerAccountService? accountService,
  })  : _authService = authService ?? TravellerAuthService(),
        _accountService = accountService ?? TravellerAccountService();

  final TravellerAuthService _authService;
  final TravellerAccountService _accountService;

  StreamSubscription<User?>? _authSubscription;

  TravellerAccount? _currentTravellerAccount;
  TravellerGroupContext? _currentGroup;
  bool _isLoading = false;
  String? _errorMessage;

  TravellerAccount? get currentTravellerAccount => _currentTravellerAccount;
  TravellerGroupContext? get currentGroup => _currentGroup;
  bool get isAuthenticated => _currentTravellerAccount != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initializeFromGroupLink(String routeGroupCode) async {
    _setState(isLoading: true, clearError: true);

    try {
      final group = await _accountService.resolveGroupByCode(routeGroupCode);
      await _authService.initialize();
      _setState(isLoading: false, currentGroup: group, updateGroup: true);

      _authSubscription ??= _authService.authStateChanges().listen(
        _onAuthStateChanged,
        onError: (error, stackTrace) {
          print('Traveller auth state listener error: $error');
          print('Traveller auth state listener stack: $stackTrace');
          _setState(
            isLoading: false,
            errorMessage: 'Unable to restore traveller session.',
          );
        },
      );
    } on TravellerAccountException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
    } catch (error, stackTrace) {
      print('Traveller link stage: unexpected exception $error');
      print('Traveller link stage: stack $stackTrace');
      _setState(
        isLoading: false,
        errorMessage: 'Unable to load traveller entry right now.',
      );
    }
  }

  Future<void> firstTimeSetup({
    required String mobile,
    required String password,
    required String confirmPassword,
  }) async {
    final group = _currentGroup;
    if (group == null) {
      _setState(errorMessage: 'Invalid traveller link.');
      return;
    }

    _setState(isLoading: true, clearError: true);

    try {
      print('Signup stage: signup started');
      if (password != confirmPassword) {
        throw const TravellerAccountException('Passwords do not match.');
      }

      final sanitizedPhone = sanitizeTravellerPhone(mobile);
      print('Signup stage: phone sanitized phone=$sanitizedPhone');
      if (sanitizedPhone.isEmpty) {
        throw const TravellerAccountException('Enter a valid mobile number.');
      }

      final authEmail = mapTravellerPhoneToAuthEmail(sanitizedPhone);
      print('Signup stage: auth email generated email=$authEmail');

      print('Signup stage: Firebase Auth create-user started');
      final credential = await _authService.createTravellerCredential(
        email: authEmail,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw const TravellerAuthException('Could not resolve auth identity.');
      }
      print('Signup stage: Firebase Auth create-user success uid=$uid');

      try {
        await _accountService.createTravellerAccountAndInitialTraveller(
          uid: uid,
          phone: sanitizedPhone,
          group: group,
        );
      } on TravellerAccountException {
        try {
          await credential.user?.delete();
        } catch (_) {}
        rethrow;
      }

      final refreshed = await _accountService.getTravellerByUid(uid);
      if (refreshed == null) {
        throw const TravellerAccountException(
          'Traveller account is missing after signup. Please contact support.',
        );
      }

      _accountService.validateAccountForGroup(
        account: refreshed,
        groupId: group.id,
        stage: 'Signup stage',
      );

      print('Signup stage: navigation started');
      _setState(
        isLoading: false,
        currentTravellerAccount: refreshed,
        updateAccount: true,
      );
    } on TravellerAccountException catch (error, stackTrace) {
      print('Signup stage: caught exception message=${error.message}');
      print('Signup stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerAuthException catch (error, stackTrace) {
      print('Signup stage: caught exception message=${error.message}');
      print('Signup stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerIdentityMapperException catch (error, stackTrace) {
      print('Signup stage: caught exception message=${error.message}');
      print('Signup stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } catch (error, stackTrace) {
      print('Signup stage: caught exception message=$error');
      print('Signup stage: stack $stackTrace');
      _setState(
        isLoading: false,
        errorMessage: 'Unable to complete signup. Please try again.',
      );
    }
  }

  Future<void> login({
    required String mobile,
    required String password,
  }) async {
    final group = _currentGroup;
    if (group == null) {
      _setState(errorMessage: 'Invalid traveller link.');
      return;
    }

    _setState(isLoading: true, clearError: true);

    try {
      print('traveller login started');
      final sanitizedPhone = sanitizeTravellerPhone(mobile);
      if (sanitizedPhone.isEmpty) {
        throw const TravellerAccountException('Enter a valid mobile number.');
      }

      final authEmail = mapTravellerPhoneToAuthEmail(sanitizedPhone);
      print('auth email generated email=$authEmail');

      await _authService.signInTraveller(
        email: authEmail,
        password: password,
      );
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        throw const TravellerAuthException('Could not resolve auth identity.');
      }
      print('Firebase Auth sign-in success uid=$uid');

      print('traveller_accounts direct lookup started');
      final refreshed = await _accountService.getTravellerByUid(uid);
      if (refreshed == null) {
        print('traveller_accounts missing');
        throw const TravellerAccountException(
          'Traveller account is missing after login. Please contact support.',
        );
      }
      print('traveller_accounts found');

      if (refreshed.isActive) {
        print('traveller account active');
      } else {
        print('traveller account inactive');
        throw const TravellerAccountException(
          'This traveller account is inactive. Please contact support.',
        );
      }

      print('current group id resolved groupId=${group.id}');
      if (refreshed.groupIds.contains(group.id)) {
        print('group membership valid');
      } else {
        print('group membership invalid');
        throw const TravellerAccountException(
          'This account is not linked to this group.',
        );
      }

      print('travellers query started');
      final travellerQuery = await _accountService.getTravellerRecordsForGroup(
        uid: uid,
        groupId: group.id,
      );
      print('travellers query result count=${travellerQuery.docs.length}');
      if (travellerQuery.docs.isEmpty) {
        throw const TravellerAccountException(
          'No traveller record found for this group. Please contact support.',
        );
      }

      print('navigation started');
      _setState(
        isLoading: false,
        currentTravellerAccount: refreshed,
        updateAccount: true,
      );
    } on TravellerAccountException catch (error, stackTrace) {
      print('caught exception message=${error.message}');
      print('Existing login stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerAuthException catch (error, stackTrace) {
      print('caught exception message=${error.message}');
      print('Existing login stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerIdentityMapperException catch (error, stackTrace) {
      print('caught exception message=${error.message}');
      print('Existing login stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } catch (error, stackTrace) {
      print('caught exception message=$error');
      print('Existing login stage: stack $stackTrace');
      _setState(
        isLoading: false,
        errorMessage: 'Traveller access loading error. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    _setState(isLoading: true, clearError: true);
    try {
      await _authService.signOut();
      _setState(
        isLoading: false,
        currentTravellerAccount: null,
        updateAccount: true,
      );
    } on TravellerAuthException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
    }
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _setState(currentTravellerAccount: null, updateAccount: true);
      return;
    }

    try {
      final account = await _accountService.getTravellerByUid(firebaseUser.uid);
      if (account == null) {
        _setState(
          currentTravellerAccount: null,
          updateAccount: true,
        );
        return;
      }

      final group = _currentGroup;
      if (group != null) {
        _accountService.validateAccountForGroup(
          account: account,
          groupId: group.id,
          stage: 'Auth state stage',
        );
      }

      _setState(currentTravellerAccount: account, updateAccount: true);
    } on TravellerAccountException catch (error) {
      await _authService.signOut();
      _setState(errorMessage: error.message);
    }
  }

  void _setState({
    TravellerAccount? currentTravellerAccount,
    bool updateAccount = false,
    TravellerGroupContext? currentGroup,
    bool updateGroup = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    if (updateAccount) {
      _currentTravellerAccount = currentTravellerAccount;
    }
    if (updateGroup) {
      _currentGroup = currentGroup;
    }
    if (isLoading != null) {
      _isLoading = isLoading;
    }
    if (clearError) {
      _errorMessage = null;
    } else if (errorMessage != null) {
      _errorMessage = errorMessage;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
