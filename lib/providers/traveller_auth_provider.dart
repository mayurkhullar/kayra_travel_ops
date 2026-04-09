import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/traveller_account.dart';
import '../models/traveller_group_context.dart';
import '../services/traveller_account_service.dart';
import '../services/traveller_auth_service.dart';

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
  }) async {
    final group = _currentGroup;
    if (group == null) {
      _setState(errorMessage: 'Invalid traveller link.');
      return;
    }

    _setState(isLoading: true, clearError: true);

    try {
      final accountLookup = await _accountService.findByPhone(mobile);
      if (accountLookup == null) {
        throw const TravellerAccountException('Mobile number not found.');
      }

      final account = accountLookup.account;
      _accountService.validateAccountForGroup(
        account: account,
        groupId: group.id,
        stage: 'First-time setup stage',
      );

      if (account.isInitialized) {
        throw const TravellerAccountException(
          'This traveller account is already initialized. Please use existing login.',
        );
      }

      final authEmail = _accountService.buildTravellerAuthEmail(
        account.phone ?? mobile,
      );
      print('First-time setup stage: auth email generated email=$authEmail');

      final credential = await _authService.createTravellerCredential(
        email: authEmail,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw const TravellerAuthException('Could not resolve auth identity.');
      }
      print('First-time setup stage: Firebase Auth user created uid=$uid');

      await _accountService.upsertCanonicalTravellerAccount(
        source: accountLookup,
        uid: uid,
        authEmail: authEmail,
      );

      final refreshed = await _accountService.getTravellerByUid(uid);
      if (refreshed == null) {
        throw const TravellerAccountException(
          'Traveller account mapping could not be completed.',
        );
      }
      _accountService.validateAccountForGroup(
        account: refreshed,
        groupId: group.id,
        stage: 'First-time setup stage',
      );

      print('First-time setup stage: auto-login/navigation starting uid=$uid');
      _setState(
        isLoading: false,
        currentTravellerAccount: refreshed,
        updateAccount: true,
      );
    } on TravellerAccountException catch (error, stackTrace) {
      print('First-time setup stage: exception ${error.message}');
      print('First-time setup stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerAuthException catch (error, stackTrace) {
      print('First-time setup stage: auth exception ${error.message}');
      print('First-time setup stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } catch (error, stackTrace) {
      print('First-time setup stage: unexpected exception $error');
      print('First-time setup stage: stack $stackTrace');
      _setState(
        isLoading: false,
        errorMessage: 'Unable to complete setup. Please try again.',
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
      print('Existing login stage: existing login started mobile=${mobile.trim()}');
      final authEmail = _accountService.buildTravellerAuthEmail(mobile);
      print('Existing login stage: auth email generated email=$authEmail');

      final credential = await _authService.signInTraveller(
        email: authEmail,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw const TravellerAuthException('Could not resolve auth identity.');
      }
      print('Existing login stage: Firebase Auth sign-in success with uid=$uid');

      final refreshed = await _accountService.getTravellerByUid(uid);
      if (refreshed == null) {
        throw const TravellerAccountException(
          'Traveller account is missing after login. Please contact support.',
        );
      }

      _accountService.validateAccountForGroup(
        account: refreshed,
        groupId: group.id,
        stage: 'Existing login stage',
      );

      print('Existing login stage: navigation starting uid=$uid');
      _setState(
        isLoading: false,
        currentTravellerAccount: refreshed,
        updateAccount: true,
      );
    } on TravellerAccountException catch (error, stackTrace) {
      print('Existing login stage: exception ${error.message}');
      print('Existing login stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerAuthException catch (error, stackTrace) {
      print('Existing login stage: auth exception ${error.message}');
      print('Existing login stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } catch (error, stackTrace) {
      print('Existing login stage: unexpected exception $error');
      print('Existing login stage: stack $stackTrace');
      _setState(
        isLoading: false,
        errorMessage: 'Unable to login right now. Please try again.',
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
