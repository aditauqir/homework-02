import 'package:firebase_auth/firebase_auth.dart';

/// Centralizes all Firebase Authentication operations.
///
/// Keeps auth state, login, registration, and logout logic outside of UI widgets.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stable stream that emits the current user on every auth change.
  late final Stream<User?> authState = _auth.authStateChanges();

  /// Current signed-in user or null.
  User? get currentUser => _auth.currentUser;

  /// Registers a new user with email and password.
  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs in an existing user with email and password.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() => _auth.signOut();

  /// Connects to the local Firebase Auth emulator for testing (Spice #1).
  Future<void> useEmulator({
    String host = '10.0.2.2', // 10.0.2.2 maps to host localhost in Android emulator
    int port = 9099,
  }) async {
    await _auth.useAuthEmulator(host, port);
  }

  /// Translates raw exceptions into clear, human-readable feedback.
  static String getFriendlyErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'The email address format is not valid.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Invalid email or password. Please check and try again.';
        case 'email-already-in-use':
          return 'An account already exists for this email address.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled on the server.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 6 characters.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection and try again.';
        case 'too-many-requests':
          return 'Too many failed attempts. Please wait a moment and try again.';
        default:
          return error.message ?? 'Authentication error occurred.';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
