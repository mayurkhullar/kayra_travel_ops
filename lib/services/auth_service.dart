import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentFirebaseUser => _firebaseAuth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseAuthError(error));
    } catch (_) {
      throw const AuthException(
        'Unable to sign in right now. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseAuthError(error));
    } catch (_) {
      throw const AuthException(
        'Unable to sign out right now. Please try again.',
      );
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
