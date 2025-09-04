import 'package:firebase_auth/firebase_auth.dart';

class Auth {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Auth();

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> login(email, password) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<UserCredential> register(email, password) async {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> configureWebPersistence() async {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }
}
