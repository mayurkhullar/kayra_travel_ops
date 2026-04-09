import 'package:firebase_auth/firebase_auth.dart';

class TravellerAuthService {
  TravellerAuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> createTravellerCredential({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw TravellerAuthException(_mapError(error));
    } catch (_) {
      throw const TravellerAuthException(
        'Unable to complete first-time setup right now. Please try again.',
      );
    }
  }

  Future<UserCredential> signInTraveller({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
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

  Future<bool> authAccountExistsForEmail(String email) async {
    try {
      final methods = await _firebaseAuth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } on FirebaseAuthException catch (error) {
      throw TravellerAuthException(_mapError(error));
    } catch (_) {
      throw const TravellerAuthException(
        'Unable to verify traveller account right now. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw TravellerAuthException(_mapError(error));
    } catch (_) {
      throw const TravellerAuthException('Unable to logout right now.');
    }
  }

  String _mapError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
        return 'Wrong password. Please try again.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your mobile number and password.';
      case 'user-not-found':
        return 'Mapped traveller auth account not found.';
      case 'email-already-in-use':
        return 'This traveller account has already been initialized.';
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
