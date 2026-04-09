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
      print('First-time setup stage: setup started mobile=${mobile.trim()}');
      if (password != confirmPassword) {
        throw const TravellerAccountException('Passwords do not match.');
      }

      print('First-time setup stage: phone lookup started');
      final accountLookup = await _accountService.findByPhone(mobile);
      if (accountLookup == null) {
        throw const TravellerAccountException('Mobile number not found.');
      }

      final account = accountLookup.account;
      print(
        'First-time setup stage: eligible traveller found docId=${accountLookup.documentId}',
      );
      _accountService.validateAccountForGroup(
        account: account,
        groupId: group.id,
        stage: 'First-time setup stage',
      );

      final authEmail = mapTravellerPhoneToAuthEmail(account.phone ?? mobile);
      print('First-time setup stage: mapped auth email generated email=$authEmail');

      final authAlreadyExists =
          await _authService.authAccountExistsForEmail(authEmail);
      if (authAlreadyExists || account.isInitialized) {
        throw const TravellerAccountException(
          'This traveller account is already initialized. Please use existing login.',
        );
      }

      print('First-time setup stage: Firebase Auth create user started');

      final credential = await _authService.createTravellerCredential(
        email: authEmail,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw const TravellerAuthException('Could not resolve auth identity.');
      }
      print('First-time setup stage: Firebase Auth create user success uid=$uid');

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

      print('First-time setup stage: setup navigation started uid=$uid');
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
    } on TravellerIdentityMapperException catch (error, stackTrace) {
      print('First-time setup stage: identity mapper exception ${error.message}');
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
      final authEmail = mapTravellerPhoneToAuthEmail(mobile);
      print('Existing login stage: mapped auth email generated email=$authEmail');

      final authAccountExists = await _authService.authAccountExistsForEmail(authEmail);
      if (!authAccountExists) {
        throw const TravellerAuthException('Mapped auth account not found.');
      }

      print('Existing login stage: Firebase Auth sign-in started');

      final credential = await _authService.signInTraveller(
        email: authEmail,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw const TravellerAuthException('Could not resolve auth identity.');
      }
      print('Existing login stage: Firebase Auth sign-in success uid=$uid');

      print('Existing login stage: canonical traveller doc lookup started uid=$uid');
      final refreshed = await _accountService.getTravellerByUid(uid);
      if (refreshed == null) {
        print('Existing login stage: canonical traveller doc missing uid=$uid');
        throw const TravellerAccountException(
          'Traveller account is missing after login. Please contact support.',
        );
      }
      print('Existing login stage: canonical traveller doc found uid=$uid');

      try {
        _accountService.validateAccountForGroup(
          account: refreshed,
          groupId: group.id,
          stage: 'Existing login stage',
        );
      } on TravellerAccountException {
        print('Existing login stage: group membership invalid uid=$uid');
        rethrow;
      }
      print('Existing login stage: group membership valid uid=$uid');

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
      print('Existing login stage: auth exception message=${error.message}');
      print('Existing login stage: stack $stackTrace');
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerIdentityMapperException catch (error, stackTrace) {
      print('Existing login stage: identity mapper exception ${error.message}');
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
      print(
        'Auth state stage: canonical traveller doc lookup started uid=${firebaseUser.uid}',
      );
      final account = await _accountService.getTravellerByUid(firebaseUser.uid);
      if (account == null) {
        print(
          'Auth state stage: canonical traveller doc missing uid=${firebaseUser.uid}',
        );
        _setState(
          currentTravellerAccount: null,
          updateAccount: true,
        );
        return;
      }
      print('Auth state stage: canonical traveller doc found uid=${firebaseUser.uid}');

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
