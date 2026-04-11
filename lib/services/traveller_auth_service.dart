import 'package:firebase_auth/firebase_auth.dart';

import 'traveller_web_auth_context.dart';

class TravellerAuthService {
  TravellerAuthService({FirebaseAuth? firebaseAuth}) : _firebaseAuth = firebaseAuth;

  FirebaseAuth? _firebaseAuth;

  Future<void> initialize() async {
    _firebaseAuth ??= await resolveTravellerAuthInstance();
  }

  Stream<User?> authStateChanges() {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw const TravellerAuthException(
        'Traveller auth is not initialized. Please try again.',
      );
    }
    return auth.authStateChanges();
  }

  User? get currentUser => _firebaseAuth?.currentUser;

  Future<UserCredential> createTravellerCredential({
    required String email,
    required String password,
  }) async {
    await initialize();

    try {
      return await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        throw const TravellerAuthException('Account already exists. Please log in.');
      }
      throw TravellerAuthException(_mapError(error));
    } catch (_) {
      throw const TravellerAuthException(
        'Unable to sign up right now. Please try again.',
      );
    }
  }

  Future<UserCredential> signInTraveller({
    required String email,
    required String password,
  }) async {
    await initialize();

    try {
      return await _firebaseAuth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw TravellerAuthException(_mapError(error));
    } catch (_) {
      throw const TravellerAuthException(
        'Unable to login right now. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    await initialize();

    try {
      await _firebaseAuth!.signOut();
    } on FirebaseAuthException catch (error) {
      throw TravellerAuthException(_mapError(error));
    } catch (_) {
      throw const TravellerAuthException('Unable to logout right now.');
    }
  }

  String _mapError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid login credentials. Please check your mobile number and password.';
      case 'user-not-found':
        return 'No account found for this mobile number. Please sign up first.';
      case 'email-already-in-use':
        return 'Account already exists. Please log in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}

class TravellerAuthException implements Exception {
  const TravellerAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
