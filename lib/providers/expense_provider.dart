import 'dart:async';
import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../models/settlement_model.dart';
import '../services/firestore_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<ExpenseModel> _expenses = [];
  List<SettlementModel> _settlements = [];
  bool _loadingExpenses = false;
  bool _loadingSettlements = false;
  bool _isDisposed = false;
  String? _currentGroupId;
  
  StreamSubscription? _expensesSubscription;
  StreamSubscription? _settlementsSubscription;
  
  // DateTime _lastExpensesLoadTime = DateTime(1970); // Comentado para simplificar
  // DateTime _lastSettlementsLoadTime = DateTime(1970); // Comentado para simplificar

  List<ExpenseModel> get expenses => _expenses;
  List<SettlementModel> get settlements => _settlements;
  bool get loadingExpenses => _loadingExpenses;
  bool get loadingSettlements => _loadingSettlements;
  String? get currentGroupId => _currentGroupId;

  Future<void> loadExpenses(String groupId, {bool forceRefresh = false}) async {
    if (_loadingExpenses && !forceRefresh && groupId == _currentGroupId) return;

    if (_currentGroupId != groupId) {
      // Si el ID del grupo cambia, limpiar datos anteriores y cancelar stream.
      _expenses = [];
      await _expensesSubscription?.cancel();
      _expensesSubscription = null;
      _currentGroupId = groupId;
      _loadingExpenses = true; // Iniciar carga para el nuevo grupo
      if (!_isDisposed) notifyListeners();
    } else {
      _loadingExpenses = true;
      if (!_isDisposed) notifyListeners();
    }
    
    bool loadedFromCacheSuccessfully = false;

    if (!forceRefresh) {
      try {
        final cachedExpenses = await _firestoreService.getExpensesOnce(groupId);
        if (!_isDisposed && cachedExpenses.isNotEmpty) {
          _expenses = cachedExpenses;
          loadedFromCacheSuccessfully = true;
          print("ExpenseProvider: Gastos cargados desde caché para el grupo $groupId.");
        } else if (!_isDisposed && cachedExpenses.isEmpty && _expenses.isNotEmpty && _currentGroupId == groupId) {
            print("ExpenseProvider: Caché de gastos vacía, pero se conservan gastos previos del grupo $groupId.");
            loadedFromCacheSuccessfully = true;
        }
      } catch (e) {
        print("Error al cargar gastos desde caché en Provider para el grupo $groupId: $e");
      }
    }

    bool shouldFetchFromNetwork = forceRefresh || !loadedFromCacheSuccessfully;

    if (shouldFetchFromNetwork) {
      print("ExpenseProvider: Necesita obtener gastos de la red para el grupo $groupId. Forzado: $forceRefresh, Éxito Caché: $loadedFromCacheSuccessfully");
      await _expensesSubscription?.cancel(); // Cancelar cualquier stream anterior
      _expensesSubscription = null;

      _expensesSubscription = _firestoreService.getExpenses(groupId).listen((expenseList) {
        if (_isDisposed || _currentGroupId != groupId) return;
        _expenses = expenseList;
        _loadingExpenses = false;
        print("ExpenseProvider: Gastos actualizados desde stream para el grupo $groupId.");
        if (!_isDisposed) notifyListeners();
      }, onError: (error) {
        if (_isDisposed || _currentGroupId != groupId) return;
        print("Error en stream de gastos para el grupo $groupId: $error");
        _loadingExpenses = false;
        if (!_isDisposed) notifyListeners();
      });
    } else {
      _loadingExpenses = false;
      print("ExpenseProvider: Usando gastos de caché para el grupo $groupId, no se inicia nuevo stream/fetch.");
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> addExpense(ExpenseModel expense) async {
    _loadingExpenses = true;
    if(!_isDisposed) notifyListeners();
    try {
      await _firestoreService.addExpense(expense);
      // Forzar refresco de los gastos del grupo correspondiente
      if (_currentGroupId == expense.groupId) {
        await loadExpenses(expense.groupId, forceRefresh: true);
      } else {
        // Si el gasto es para un grupo diferente al actual, no necesariamente refrescamos,
        // o podríamos decidir cargar ese grupo si la UX lo requiere.
        // Por ahora, solo actualizamos si es el grupo actual.
        _loadingExpenses = false; // Terminar carga si no se refresca
        if(!_isDisposed) notifyListeners();
      }
    } catch (e) {
      print("Error al añadir gasto: $e");
      _loadingExpenses = false;
      if(!_isDisposed) notifyListeners();
    }
  }

  Future<void> loadSettlements(String groupId, {bool forceRefresh = false}) async {
    if (_loadingSettlements && !forceRefresh && groupId == _currentGroupId) return;

    // Asumimos que _currentGroupId ya está seteado por loadExpenses o es el mismo.
    // Si esta función se puede llamar independientemente, se necesitaría una lógica similar
    // a loadExpenses para manejar el cambio de _currentGroupId.
    if (_currentGroupId != groupId) {
        _settlements = [];
        await _settlementsSubscription?.cancel();
        _settlementsSubscription = null;
        // No actualizamos _currentGroupId aquí, asumimos que loadExpenses lo maneja
        // o que el groupId proporcionado es el contexto deseado.
        _loadingSettlements = true;
        if (!_isDisposed) notifyListeners();
    } else {
        _loadingSettlements = true;
        if (!_isDisposed) notifyListeners();
    }

    bool loadedFromCacheSuccessfully = false;

    if (!forceRefresh) {
      try {
        final cachedSettlements = await _firestoreService.getSettlementsOnce(groupId);
        if (!_isDisposed && cachedSettlements.isNotEmpty) {
          _settlements = cachedSettlements;
          loadedFromCacheSuccessfully = true;
          print("ExpenseProvider: Liquidaciones cargadas desde caché para el grupo $groupId.");
        } else if (!_isDisposed && cachedSettlements.isEmpty && _settlements.isNotEmpty && _currentGroupId == groupId) {
            print("ExpenseProvider: Caché de liquidaciones vacía, pero se conservan liquidaciones previas del grupo $groupId.");
            loadedFromCacheSuccessfully = true;
        }
      } catch (e) {
        print("Error al cargar liquidaciones desde caché en Provider para el grupo $groupId: $e");
      }
    }

    bool shouldFetchFromNetwork = forceRefresh || !loadedFromCacheSuccessfully;

    if (shouldFetchFromNetwork) {
      print("ExpenseProvider: Necesita obtener liquidaciones de la red para el grupo $groupId. Forzado: $forceRefresh, Éxito Caché: $loadedFromCacheSuccessfully");
      await _settlementsSubscription?.cancel();
      _settlementsSubscription = null;

      _settlementsSubscription = _firestoreService.getSettlements(groupId).listen((settlementList) {
        if (_isDisposed || _currentGroupId != groupId) return;
        _settlements = settlementList;
        _loadingSettlements = false;
        print("ExpenseProvider: Liquidaciones actualizadas desde stream para el grupo $groupId.");
        if (!_isDisposed) notifyListeners();
      }, onError: (error) {
        if (_isDisposed || _currentGroupId != groupId) return;
        print("Error en stream de liquidaciones para el grupo $groupId: $error");
        _loadingSettlements = false;
        if (!_isDisposed) notifyListeners();
      });
    } else {
      _loadingSettlements = false;
      print("ExpenseProvider: Usando liquidaciones de caché para el grupo $groupId, no se inicia nuevo stream/fetch.");
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> addSettlement(SettlementModel settlement) async {
    _loadingSettlements = true;
    if(!_isDisposed) notifyListeners();
    try {
      await _firestoreService.addSettlement(settlement);
      if (_currentGroupId == settlement.groupId) {
        await loadSettlements(settlement.groupId, forceRefresh: true);
      }
       else {
        _loadingSettlements = false; 
        if(!_isDisposed) notifyListeners();
      }
    } catch (e) {
      print("Error al añadir liquidación: $e");
      _loadingSettlements = false;
      if(!_isDisposed) notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _expensesSubscription?.cancel();
    _expensesSubscription = null;
    _settlementsSubscription?.cancel();
    _settlementsSubscription = null;
    super.dispose();
  }
  
  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
