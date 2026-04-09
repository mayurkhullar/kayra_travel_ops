import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, UserService? userService})
      : _authService = authService ?? AuthService(),
        _userService = userService ?? UserService();

  final AuthService _authService;
  final UserService _userService;

  StreamSubscription<User?>? _authSubscription;

  AppUser? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasInitialized = false;

  AppUser? get currentUser => _currentUser;
  String? get role => _currentUser?.role;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void initialize() {
    if (_hasInitialized) {
      return;
    }
    _hasInitialized = true;

    _authSubscription ??= _authService.authStateChanges().listen(
      (firebaseUser) {
        _handleAuthChanged(firebaseUser);
      },
      onError: (Object error) {
        _setState(
          isLoading: false,
          errorMessage: 'Authentication listener failed: $error',
          currentUser: null,
          updateUser: true,
        );
      },
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    _setState(isLoading: true, clearError: true);

    try {
      final credential = await _authService.signIn(email: email, password: password);
      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthException('Unable to resolve signed-in user.');
      }

      await _bootstrapUser(firebaseUser);
    } on AuthException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
      rethrow;
    } on UserException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
      rethrow;
    } catch (_) {
      _setState(
        isLoading: false,
        errorMessage: 'Unexpected error while signing in.',
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    _setState(isLoading: true, clearError: true);

    try {
      await _authService.signOut();
      _setState(isLoading: false, currentUser: null, updateUser: true, clearError: true);
    } on AuthException catch (error) {
      _setState(isLoading: false, errorMessage: error.message);
      rethrow;
    } catch (_) {
      _setState(
        isLoading: false,
        errorMessage: 'Unexpected error while signing out.',
      );
      rethrow;
    }
  }

  Future<void> _handleAuthChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _setState(isLoading: false, currentUser: null, updateUser: true, clearError: true);
      return;
    }

    _setState(isLoading: true, clearError: true);

    try {
      await _bootstrapUser(firebaseUser);
    } on AuthException catch (error) {
      _setState(
        isLoading: false,
        currentUser: null,
        errorMessage: error.message,
        updateUser: true,
      );
    } on UserException catch (error) {
      _setState(
        isLoading: false,
        currentUser: null,
        errorMessage: error.message,
        updateUser: true,
      );
    } catch (_) {
      _setState(
        isLoading: false,
        currentUser: null,
        errorMessage: 'Unable to restore session. Please log in again.',
        updateUser: true,
      );
    }
  }

  Future<void> _bootstrapUser(User firebaseUser) async {
    final profile = await _userService.fetchOrCreateUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
    );

    _setState(
      isLoading: false,
      currentUser: profile,
      updateUser: true,
      clearError: true,
    );
  }

  void _setState({
    bool? isLoading,
    AppUser? currentUser,
    bool updateUser = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    _isLoading = isLoading ?? _isLoading;
    if (updateUser) {
      _currentUser = currentUser;
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
    _authSubscription = null;
    super.dispose();
  }
}
