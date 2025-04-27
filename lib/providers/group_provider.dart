import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../services/firestore_service.dart';

class GroupProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<GroupModel> _groups = [];
  bool _loading = false;

  List<GroupModel> get groups => _groups;
  bool get loading => _loading;

  Future<void> loadUserGroups(String userId) async {
    _loading = true;
    notifyListeners();
    _firestoreService.getUserGroups(userId).listen((groupList) {
      _groups = groupList;
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
}
