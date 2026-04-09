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
    print('Traveller login: route/group code received code=${routeGroupCode.trim()}');
    _setState(isLoading: true, clearError: true);

    try {
      final group = await _accountService.resolveGroupByCode(routeGroupCode);
      _setState(isLoading: false, currentGroup: group, updateGroup: true);

      _authSubscription ??= _authService.authStateChanges().listen(
        _onAuthStateChanged,
        onError: (_) {
          _setState(
            isLoading: false,
            errorMessage: 'Unable to restore traveller session.',
          );
        },
      );
    } on TravellerAccountException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
    } catch (_) {
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
      _setState(errorMessage: 'Group context missing for setup.');
      return;
    }

    _setState(isLoading: true, clearError: true);

    try {
      final account = await _accountService.findByPhone(mobile);
      if (account == null) {
        throw const TravellerAccountException('Mobile number not found.');
      }
      _accountService.validateAccountForGroup(account: account, groupId: group.id);

      if (account.isInitialized) {
        throw const TravellerAccountException(
          'First-time setup already completed for this mobile number.',
        );
      }

      final authEmail = _accountService.buildTravellerAuthEmail(
        account.phone ?? mobile,
      );
      final credential = await _authService.createTravellerCredential(
        email: authEmail,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid == null) {
        throw const TravellerAuthException('Could not resolve auth identity.');
      }

      await _accountService.attachAuthToTravellerAccount(
        travellerId: account.id,
        authUid: uid,
        authEmail: authEmail,
      );

      final refreshed = await _accountService.getTravellerByAuthUid(uid);
      if (refreshed == null) {
        throw const TravellerAccountException(
          'Traveller account mapping could not be completed.',
        );
      }
      _accountService.validateAccountForGroup(account: refreshed, groupId: group.id);

      _setState(
        isLoading: false,
        currentTravellerAccount: refreshed,
        updateAccount: true,
      );
    } on TravellerAccountException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerAuthException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
    } catch (_) {
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
      _setState(errorMessage: 'Group context missing for login.');
      return;
    }

    _setState(isLoading: true, clearError: true);

    try {
      print('Traveller login attempt starting mobile=${mobile.trim()}');
      final account = await _accountService.findByPhone(mobile);
      if (account == null) {
        throw const TravellerAccountException('Mobile number not found.');
      }
      print('Traveller login: group access validation starting groupId=${group.id}');
      _accountService.validateAccountForGroup(account: account, groupId: group.id);

      if (!account.isInitialized) {
        throw const TravellerAccountException(
          'First-time setup is required before login.',
        );
      }

      final authEmail = _accountService.buildTravellerAuthEmail(
        account.phone ?? mobile,
      );

      final credential = await _authService.signInTraveller(
        email: authEmail,
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) {
        throw const TravellerAuthException('Could not resolve auth identity.');
      }
      print('Traveller login: Firebase Auth login success uid=$uid');

      if (account.authUid != uid) {
        throw const TravellerAccountException(
          'This traveller login does not match your account mapping.',
        );
      }

      print('Traveller account read starting uid=$uid');
      final refreshed = await _accountService.getTravellerByAuthUid(uid);
      if (refreshed == null) {
        print('Traveller account read: failure uid=$uid reason=not_found');
        throw const TravellerAccountException(
          'Traveller account mapping is missing for this login.',
        );
      }
      print('Traveller account read: success uid=$uid');
      print('Traveller login: group access validation starting groupId=${group.id}');
      _accountService.validateAccountForGroup(account: refreshed, groupId: group.id);

      _setState(
        isLoading: false,
        currentTravellerAccount: refreshed,
        updateAccount: true,
      );
    } on TravellerAccountException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
    } on TravellerAuthException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
    } catch (_) {
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
      print('Traveller account read starting uid=${firebaseUser.uid}');
      final account = await _accountService.getTravellerByAuthUid(firebaseUser.uid);
      if (account == null) {
        print('Traveller account read: failure uid=${firebaseUser.uid} reason=not_found');
        _setState(
          currentTravellerAccount: null,
          updateAccount: true,
        );
        return;
      }
      print('Traveller account read: success uid=${firebaseUser.uid}');

      final group = _currentGroup;
      if (group != null && !account.groupIds.contains(group.id)) {
        await _authService.signOut();
        _setState(
          errorMessage: 'This traveller account is not linked to this group.',
        );
        return;
      }
      if (!account.isActive) {
        await _authService.signOut();
        _setState(
          errorMessage:
              'This traveller account is inactive. Please contact support.',
        );
        return;
      }

      _setState(currentTravellerAccount: account, updateAccount: true);
    } on TravellerAccountException catch (error) {
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
