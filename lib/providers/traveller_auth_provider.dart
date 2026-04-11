import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isLoginBootstrapInProgress = false;
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
    _isLoginBootstrapInProgress = true;

    try {
      _log('Login started');
      _log('Raw phone input: $mobile');
      final sanitizedPhone = sanitizeTravellerPhone(mobile);
      _log('Sanitized phone: $sanitizedPhone');
      if (sanitizedPhone.isEmpty) {
        throw const TravellerAccountException('Enter a valid mobile number.');
      }

      final authEmail = mapTravellerPhoneToAuthEmail(sanitizedPhone);
      _log('Mapped auth email: $authEmail');

      _log('Firebase sign-in started');
      try {
        await _authService.signInTraveller(
          email: authEmail,
          password: password,
        );
      } catch (error, stackTrace) {
        _logError('sign-in failure', error, stackTrace);
        rethrow;
      }

      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        throw const TravellerAuthException('Could not resolve auth identity.');
      }
      _log('Firebase sign-in success: uid=$uid');

      _log('Loading traveller_accounts/$uid');
      final refreshed = await _loadTravellerAccount(uid);
      if (refreshed == null) {
        throw const TravellerAccountException(
          'Traveller account setup is missing. Please contact support.',
        );
      }
      _log('traveller_accounts exists: true');
      _log(
        'traveller_accounts data: {id: ${refreshed.id}, isActive: ${refreshed.isActive}, groupIds: ${refreshed.groupIds}}',
      );

      _validateActiveAccount(refreshed);

      _log('Current group id: ${group.id}');
      _validateGroupMembership(account: refreshed, groupId: group.id);

      _log(
        'Querying travellers for accountId=$uid groupId=${group.id}',
      );
      final travellerQuery = await _queryTravellerContext(
        uid: uid,
        groupId: group.id,
      );
      _log('travellers query result count: ${travellerQuery.docs.length}');
      if (travellerQuery.docs.isEmpty) {
        throw const TravellerAccountException(
          'No traveller record found for this group. Please contact support.',
        );
      }

      _log('Navigation starting');
      try {
        _setState(
          isLoading: false,
          currentTravellerAccount: refreshed,
          updateAccount: true,
        );
      } catch (error, stackTrace) {
        _logError('navigation failure', error, stackTrace);
        rethrow;
      }
    } on TravellerAccountException catch (error, stackTrace) {
      _logError('group membership validation failure', error, stackTrace);
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerAuthException catch (error, stackTrace) {
      _logError('sign-in failure', error, stackTrace);
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerIdentityMapperException catch (error, stackTrace) {
      _logError('sign-in failure', error, stackTrace);
      _setState(isLoading: false, errorMessage: error.message);
    } catch (error, stackTrace) {
      _logError('traveller access loading failure', error, stackTrace);
      _setState(
        isLoading: false,
        errorMessage: 'Traveller access loading failed. Please try again.',
      );
    } finally {
      _isLoginBootstrapInProgress = false;
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
    if (_isLoginBootstrapInProgress) {
      _log('Auth-state listener ignored during login bootstrap');
      return;
    }

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

  Future<TravellerAccount?> _loadTravellerAccount(String uid) async {
    try {
      final account = await _accountService.getTravellerByUid(uid);
      _log('traveller_accounts exists: ${account != null}');
      return account;
    } catch (error, stackTrace) {
      _logError('traveller_accounts lookup failure', error, stackTrace);
      rethrow;
    }
  }

  void _validateActiveAccount(TravellerAccount account) {
    if (!account.isActive) {
      throw const TravellerAccountException(
        'This traveller account is inactive. Please contact support.',
      );
    }
  }

  void _validateGroupMembership({
    required TravellerAccount account,
    required String groupId,
  }) {
    final isLinked = account.groupIds.contains(groupId);
    _log('groupIds contains current group: $isLinked');
    if (!isLinked) {
      throw const TravellerAccountException(
        'This account is not linked to this group.',
      );
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _queryTravellerContext({
    required String uid,
    required String groupId,
  }) async {
    try {
      return await _accountService.getTravellerRecordsForGroup(
        uid: uid,
        groupId: groupId,
      );
    } catch (error, stackTrace) {
      _logError('travellers query failure', error, stackTrace);
      rethrow;
    }
  }

  void _log(String message) {
    print('[TravellerLogin] $message');
  }

  void _logError(String stage, Object error, StackTrace stackTrace) {
    print('[TravellerLogin] ERROR during $stage: $error');
    print('[TravellerLogin] STACK: $stackTrace');
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
