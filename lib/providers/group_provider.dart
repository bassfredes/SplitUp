import 'dart:async'; // Necesario para StreamSubscription

import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../services/firestore_service.dart';

class GroupProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<GroupModel> _groups = [];
  bool _loading = false;
  bool _isDisposed = false; // Bandera para controlar el estado de dispose
  StreamSubscription? _userGroupsSubscription; // Para manejar la suscripción

  List<GroupModel> get groups => _groups;
  bool get loading => _loading;

  Future<void> loadUserGroups(String userId) async {
    _loading = true;
    // Notificar inmediatamente que la carga ha comenzado, solo si no está dispuesto
    if (!_isDisposed) {
      notifyListeners();
    }

    // Cancelar cualquier suscripción anterior para evitar múltiples listeners
    await _userGroupsSubscription?.cancel();
    _userGroupsSubscription = _firestoreService.getUserGroups(userId).listen((groupList) {
      if (_isDisposed) return; // No hacer nada si ya está dispuesto
      _groups = groupList;
      _loading = false;
      notifyListeners(); // notifyListeners ya comprueba _isDisposed
    }, onError: (error) {
      if (_isDisposed) return;
      // Manejar el error apropiadamente, por ejemplo, loggearlo o mostrar un mensaje
      print("Error al cargar grupos: $error");
      _loading = false;
      notifyListeners();
    });
  }

  Future<void> createGroup(GroupModel group, String userId) async {
    await _firestoreService.createGroup(group);
    await loadUserGroups(userId);
  }

  Future<void> deleteGroup(String groupId, String userId) async {
    // Limpia gastos y liquidaciones antes de eliminar el grupo
    await _firestoreService.cleanGroupExpensesAndSettlements(groupId);
    await _firestoreService.deleteGroup(groupId);
    await loadUserGroups(userId);
  }

  Future<void> removeParticipantAndRedistribute(String groupId, String userId) async {
    await _firestoreService.removeParticipantFromExpenses(groupId, userId);
    // Aquí podrías recalcular deudas si tienes un sistema persistente de deudas
    // Por ahora solo actualizamos los gastos
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _userGroupsSubscription?.cancel(); // Cancelar la suscripción al stream
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
