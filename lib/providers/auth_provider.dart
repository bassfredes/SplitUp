import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

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
    _user = await _authService.signInWithGoogle();
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
      _loading = false;
      notifyListeners();
      return _user == null ? 'No se pudo iniciar sesión' : null;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> registerWithEmail(String email, String password, {required String name}) async {
    _loading = true;
    notifyListeners();
    try {
      _user = await _authService.registerWithEmail(email, password, name: name);
      _loading = false;
      notifyListeners();
      return _user == null ? 'No se pudo registrar' : null;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
