import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  // Iniciar sesión con GitHub (Web)
  Future<UserModel?> signInWithGitHub() async {
    // Detectar si es web
    if (identical(0, 0.0)) {
      final githubProvider = GithubAuthProvider();
      try {
        final userCredential = await _auth.signInWithPopup(githubProvider);
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
      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          final email = e.email;
          final pendingCred = e.credential;
          if (email != null && pendingCred != null) {
            // Buscar los métodos de inicio de sesión asociados a ese email
            final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
            // Si es Google
            if (signInMethods.contains('google.com')) {
              throw FirebaseAuthException(
                code: 'link-account-google',
                message: 'Este correo ya está registrado con Google. Inicia sesión con Google y luego vincula GitHub desde tu cuenta.',
                email: email,
                credential: pendingCred,
              );
            }
            // Si es email/contraseña
            if (signInMethods.contains('password')) {
              throw FirebaseAuthException(
                code: 'link-account-password',
                message: 'Este correo ya está registrado con email y contraseña. Inicia sesión con email y luego vincula GitHub desde tu cuenta.',
                email: email,
                credential: pendingCred,
              );
            }
            // Otros providers
            throw FirebaseAuthException(
              code: 'link-account-other',
              message: 'Este correo ya está registrado con otro método. Inicia sesión con ese método y vincula GitHub desde tu cuenta.',
              email: email,
              credential: pendingCred,
            );
          }
        }
        rethrow;
      }
    } else {
      // Para otras plataformas, puedes lanzar un error o manejarlo según corresponda
      throw UnimplementedError('GitHub login solo está implementado para web');
    }
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

  // Vincular cuenta de GitHub (Web, Android, iOS)
  Future<void> linkWithGitHub() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Web
    if (identical(0, 0.0)) {
      final githubProvider = GithubAuthProvider();
      try {
        await user.linkWithPopup(githubProvider);
      } catch (e) {
        if (e is FirebaseAuthException && e.code == 'popup-closed-by-user') return;
        rethrow;
      }
    } else {
      // Android/iOS: flujo OAuth manual
      const clientId = 'Iv23li1H0ikA7vE8y36E';
      const clientSecret = '1847cb78f6fe2926df4c6e5cb3ba029da10b2353';
      const redirectUri = 'https://splitup-5972d.firebaseapp.com/__/auth/handler';
      final authUrl =
          'https://github.com/login/oauth/authorize?client_id=$clientId&redirect_uri=$redirectUri&scope=read:user%20user:email';
      // Abrir navegador para login
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'splitup',
      );
      // Extraer el código de la URL
      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) throw Exception('No se pudo obtener el código de GitHub');
      // Intercambiar el código por un access token
      final tokenRes = await http.post(
        Uri.parse('https://github.com/login/oauth/access_token'),
        headers: {'Accept': 'application/json'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'redirect_uri': redirectUri,
        },
      );
      final tokenJson = json.decode(tokenRes.body);
      final accessToken = tokenJson['access_token'];
      if (accessToken == null) throw Exception('No se pudo obtener el access token de GitHub');
      // Vincular con Firebase
      final credential = GithubAuthProvider.credential(accessToken);
      await user.linkWithCredential(credential);
    }
  }

  // Vincular cuenta de Google (Web, Android, iOS)
  Future<void> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Web
    if (identical(0, 0.0)) {
      final googleProvider = GoogleAuthProvider();
      try {
        await user.linkWithPopup(googleProvider);
      } catch (e) {
        // Si el usuario cierra el popup, simplemente retorna
        if (e is FirebaseAuthException && e.code == 'popup-closed-by-user') return;
        rethrow;
      }
    } else {
      // Android/iOS
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.linkWithCredential(credential);
    }
  }

  // Desvincular cuenta de GitHub
  Future<void> unlinkGitHub() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.unlink('github.com');
    }
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
