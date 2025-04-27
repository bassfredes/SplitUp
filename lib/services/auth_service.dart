import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Iniciar sesión con Google
  Future<UserModel?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return null;
    // Guardar o actualizar usuario en Firestore
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (!docSnapshot.exists) {
      await userDoc.set({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'provider': providers,
      });
    } else {
      await userDoc.update({
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
        'provider': providers,
      });
    }
    return UserModel(
      id: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }

  // Iniciar sesión con email y contraseña
  Future<UserModel?> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final user = userCredential.user;
    if (user == null) return null;
    // Actualizar lastLogin y provider en Firestore
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final providers = user.providerData.map((p) => p.providerId).toList();
    await userDoc.update({
      'lastLogin': FieldValue.serverTimestamp(),
      'provider': providers,
    });
    return UserModel(
      id: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }

  // Registrar usuario con email, contraseña y nombre
  Future<UserModel?> registerWithEmail(String email, String password, {required String name}) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = userCredential.user;
    if (user == null) return null;
    // Actualizar el displayName en Firebase Auth
    await user.updateDisplayName(name);
    // Enviar email de verificación
    await user.sendEmailVerification();
    // Guardar datos adicionales en Firestore
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': name,
      'email': email,
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return UserModel(
      id: user.uid,
      name: name,
      email: email,
      photoUrl: user.photoURL,
    );
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  // Usuario actual
  UserModel? getCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) return null;
    return UserModel(
      id: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }

  // Stream de autenticación
  Stream<UserModel?> get userChanges {
    return _auth.authStateChanges().map((user) =>
      user == null ? null : UserModel(
        id: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      )
    );
  }
}
