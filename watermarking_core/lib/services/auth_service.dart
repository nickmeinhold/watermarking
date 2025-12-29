import 'package:firebase_auth/firebase_auth.dart';
import 'package:watermarking_core/redux/actions.dart';

class AuthService {
  AuthService();

  /// Receives [User] each time the user signIn or signOut
  Stream<ActionSetAuthState> listenToAuthState() {
    return FirebaseAuth.instance.authStateChanges().map(
        (User? user) => ActionSetAuthState(
            userId: user?.uid, photoUrl: user?.photoURL));
  }

  Future<void> signOut() {
    return FirebaseAuth.instance.signOut();
  }
}
