import 'dart:async'; // Necesario para StreamSubscription

import 'package:flutter/material.dart';
import '../models/group_model.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart'; // Import UserModel
import '../models/expense_model.dart'; // Import ExpenseModel

class GroupProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<GroupModel> _groups = [];
  Map<String, UserModel> _participantsDetails = {}; // Store participant details
  Map<String, double> _userBalances = {}; // Store user balances per group
  bool _loading = false;
  Map<String, ExpenseModel?> _lastExpenses = {}; // Store last expense per group
  bool _isDisposed = false; // Bandera para controlar el estado de dispose
  StreamSubscription? _userGroupsSubscription; // Para manejar la suscripción
  DateTime _lastLoadTime = DateTime(1970); // Para controlar la frecuencia de refrescos

  List<GroupModel> get groups => _groups;
  bool get loading => _loading;

  Map<String, double> get userBalances => _userBalances; // Expose user balances
  Map<String, UserModel> get participants => _participantsDetails; // Expose participants
  Map<String, UserModel> get participantsDetails => _participantsDetails; // Expose participants details
  Map<String, ExpenseModel?> get lastExpenses => _lastExpenses; // Expose last expenses

  Future<void> loadUserGroups(String userId) async {
    _loading = true;
    _participantsDetails = {}; // Clear participants map at the beginning
    _userBalances = {}; // Clear user balances map at the beginning
    // Notificar inmediatamente que la carga ha comenzado, solo si no está dispuesto
    if (!_isDisposed) {
      notifyListeners();
    }

    // Optimización: Intentar cargar primero desde la caché para respuesta inmediata
    try {
      final cachedGroups = await _firestoreService.getUserGroupsOnce(userId);
      if (!_isDisposed && cachedGroups.isNotEmpty) {
        await _calculateBalancesForGroups(cachedGroups, userId); // Calculate balances for cached groups
        await _fetchAndCacheParticipants(cachedGroups); // Fetch participants for cached groups
        _groups = cachedGroups;
 await _fetchLastExpensesForGroups(cachedGroups); // Fetch last expenses for cached groups
        _loading = false;
        notifyListeners();
      }
    } catch (e) {
      // Si hay error al cargar desde caché, continuamos con el stream
      print("Error al cargar grupos desde caché: $e");
    }

    // Control de frecuencia: Si se cargaron datos hace menos de 30 segundos y tenemos datos,
    // no iniciamos un nuevo stream a menos que se fuerce la recarga
    final now = DateTime.now();
    if (now.difference(_lastLoadTime).inSeconds < 30 && _groups.isNotEmpty) {
      _loading = false;
      if (!_isDisposed) notifyListeners();
      return;
    }
    
    _lastLoadTime = now;

    // Cancelar cualquier suscripción anterior para evitar múltiples listeners
    await _userGroupsSubscription?.cancel();
    _userGroupsSubscription = _firestoreService.getUserGroups(userId).listen((groupList) {
      // Ensure listener actions are not performed if disposed
      _calculateBalancesForGroups(groupList, userId).then((_) async {
        if (_isDisposed) return;
 await _fetchLastExpensesForGroups(groupList); // Fetch last expenses for the new list
        await _fetchAndCacheParticipants(groupList); // Fetch participants for the new list
        _groups = groupList;
        _loading = false;
 if (!_isDisposed) notifyListeners();
      });
    }, onError: (error) {
      if (_isDisposed) return;
      // Manejar el error apropiadamente, por ejemplo, loggearlo o mostrar un mensaje
      print("Error al cargar grupos: $error");
      _loading = false;
      notifyListeners();
    });
  }

  // Helper method to calculate balances for a list of groups
  Future<void> _calculateBalancesForGroups(List<GroupModel> groups, String userId) async {
    _userBalances = {}; // Clear previous balances
    for (final group in groups) {
      try {
        final expenses = await _firestoreService.getExpensesOnce(group.id);
        double balance = 0;
        for (final exp in expenses) {
          final paid = exp.payers.where((p) => p['userId'] == userId).fold<double>(0, (a, b) => a + (b['amount'] as num).toDouble());
          final isParticipant = exp.participantIds.contains(userId);
          final share = isParticipant
              ? (exp.splitType == 'equal' ? exp.amount / exp.participantIds.length : _getUserShare(exp, userId))
              : 0;
          balance += paid - share;
        }
        _userBalances[group.id] = balance;
      } catch (e) {
        print("Error calculating balance for group ${group.id}: $e");
        _userBalances[group.id] = 0.0; // Assign a default value in case of error
      }
    });
  }

  // Helper method to fetch last expenses for a list of groups
  Future<void> _fetchLastExpensesForGroups(List<GroupModel> groups) async {
    _lastExpenses = {}; // Clear previous last expenses
    for (final group in groups) {
 try {
 final lastExpense = await _firestoreService.getLastExpenseForGroup(group.id);
 _lastExpenses[group.id] = lastExpense;
      } catch (e) {
 print("Error fetching last expense for group ${group.id}: $e");
      }
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

  // Helper function to fetch and cache participant details
  Future<void> _fetchAndCacheParticipants(List<GroupModel> groups) async {
    final allParticipantIds = groups
        .expand((group) => group.participantIds)
        .toSet() // Use a Set to get unique IDs
        .toList();

    if (allParticipantIds.isNotEmpty) {
      try {
        final fetchedUsers = await _firestoreService.fetchUsersByIds(allParticipantIds);
        for (final user in fetchedUsers.cast<UserModel>()) {
 _participantsDetails[user.id] = user;
        }
        if (!_isDisposed) {
           notifyListeners(); // Notify after fetching participants
        }
      } catch (e) {
        print("Error fetching participant details: $e");
      }
    }
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

  // Helper for getting the user's share in an expense (copied from _GroupCardState)
  static double _getUserShare(ExpenseModel exp, String userId) {
    if (exp.splitType == 'equal') {
      return exp.amount / exp.participantIds.length;
    }
    if (exp.customSplits != null) {
      final split = exp.customSplits!.firstWhere(
        (s) => s['userId'] == userId,
        orElse: () => <String, dynamic>{},
      );
      if (split['amount'] != null) {
        return (split['amount'] as num).toDouble();
      }
    }
    return 0;
  }
}
