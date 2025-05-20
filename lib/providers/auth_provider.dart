import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _user;
  bool _loading = false;

  UserModel? get user => _user;
  bool get loading => _loading;

  AuthProvider() {
    _authService.userChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle() async {
    _loading = true;
    notifyListeners();
    try {
      _user = await _authService.signInWithGoogle();
      await FirebaseAnalytics.instance.logEvent(
        name: 'login',
        parameters: {'method': 'google'},
      );
    } catch (e) {
      if (e.toString().contains('popup-closed-by-user') || e.toString().contains('popup_closed')) {
        _loading = false;
        notifyListeners();
        return;
      }
      rethrow;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _loading = true;
    notifyListeners();
    await _authService.signOut();
    _user = null;
    _loading = false;
    notifyListeners();
  }

  Future<String?> signInWithEmail(String email, String password) async {
    _loading = true;
    notifyListeners();
    try {
      _user = await _authService.signInWithEmail(email, password);
      await FirebaseAnalytics.instance.logEvent(
        name: 'login',
        parameters: {'method': 'email'},
      );
      _loading = false;
      notifyListeners();
      return _user == null ? 'No se pudo iniciar sesión' : null;
    } catch (e) {
      _loading = false;
      notifyListeners();
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      if (errorMessage.contains('INVALID_LOGIN_CREDENTIALS') || 
          errorMessage.contains('invalid-credential') || 
          errorMessage.contains('wrong-password') || 
          errorMessage.contains('user-not-found')) {
        return 'Credenciales incorrectas. Por favor, verifica tu correo y contraseña.';
      }
      return errorMessage;
    }
  }

  Future<String?> registerWithEmail(String email, String password, {required String name}) async {
    _loading = true;
    notifyListeners();
    try {
      _user = await _authService.registerWithEmail(email, password, name: name);
      await FirebaseAnalytics.instance.logEvent(
        name: 'sign_up',
        parameters: {'method': 'email'},
      );
      _loading = false;
      notifyListeners();
      return _user == null ? 'No se pudo registrar' : null;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> signInWithGitHub() async {
    _loading = true;
    notifyListeners();
    try {
      _user = await _authService.signInWithGitHub();
      await FirebaseAnalytics.instance.logEvent(
        name: 'login',
        parameters: {'method': 'github'},
      );
      _loading = false;
      notifyListeners();
      return null;
    } on Exception catch (e) {
      if (e.toString().contains('popup-closed-by-user') || e.toString().contains('popup_closed')) {
        _loading = false;
        notifyListeners();
        return null;
      }
      _loading = false;
      notifyListeners();
      return e.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('[firebase_auth/link-account-other] ', '');
    }
  }

  Future<void> linkWithGitHub() async {
    _loading = true;
    notifyListeners();
    await _authService.linkWithGitHub();
    _user = _authService.getCurrentUser();
    _loading = false;
    notifyListeners();
  }

  Future<void> unlinkGitHub() async {
    _loading = true;
    notifyListeners();
    await _authService.unlinkGitHub();
    _user = _authService.getCurrentUser();
    _loading = false;
    notifyListeners();
  }
}
