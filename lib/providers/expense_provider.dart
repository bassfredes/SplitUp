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
  
  // Suscripciones para poder cancelarlas
  StreamSubscription? _expensesSubscription;
  StreamSubscription? _settlementsSubscription;
  
  // Control de cargas recientes
  DateTime _lastExpensesLoadTime = DateTime(1970);
  DateTime _lastSettlementsLoadTime = DateTime(1970);

  // Getters públicos
  List<ExpenseModel> get expenses => _expenses;
  List<SettlementModel> get settlements => _settlements;
  bool get loadingExpenses => _loadingExpenses;
  bool get loadingSettlements => _loadingSettlements;
  String? get currentGroupId => _currentGroupId; // Hacer público el ID del grupo actual

  Future<void> loadExpenses(String groupId) async {
    _loadingExpenses = true;
    if (!_isDisposed) notifyListeners();
    
    // Guardar el ID del grupo actual
    _currentGroupId = groupId;
    
    // Optimización: Intentar cargar primero desde la caché para respuesta inmediata
    try {
      final cachedExpenses = await _firestoreService.getExpensesOnce(groupId);
      if (!_isDisposed) {
        _expenses = cachedExpenses;
        _loadingExpenses = false;
        notifyListeners();
      }
    } catch (e) {
      // Si hay error al cargar desde caché, continuamos con el stream
      print("Error al cargar gastos desde caché: $e");
    }
    
    // Solo para depuración, verificar si hay gastos
    print("Cargados ${_expenses.length} gastos para el grupo $groupId");
    
    // Control de frecuencia: Si se cargaron datos hace menos de 60 segundos y tenemos datos,
    // no iniciamos un nuevo stream
    final now = DateTime.now();
    if (now.difference(_lastExpensesLoadTime).inSeconds < 60 && _expenses.isNotEmpty) {
      _loadingExpenses = false;
      if (!_isDisposed) notifyListeners();
      return;
    }
    
    _lastExpensesLoadTime = now;
    
    // Cancelar suscripción anterior si existe
    await _expensesSubscription?.cancel();
    
    // Suscribirse a nuevos cambios
    _expensesSubscription = _firestoreService.getExpenses(groupId).listen((expenseList) {
      if (_isDisposed) return;
      _expenses = expenseList;
      _loadingExpenses = false;
      notifyListeners();
    }, onError: (error) {
      if (_isDisposed) return;
      print("Error al cargar gastos: $error");
      _loadingExpenses = false;
      notifyListeners();
    });
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _firestoreService.addExpense(expense);
  }

  Future<void> loadSettlements(String groupId) async {
    _loadingSettlements = true;
    if (!_isDisposed) notifyListeners();
    
    // Optimización: Intentar cargar primero desde la caché para respuesta inmediata
    try {
      final cachedSettlements = await _firestoreService.getSettlementsOnce(groupId);
      if (!_isDisposed) {
        _settlements = cachedSettlements;
        _loadingSettlements = false;
        notifyListeners();
      }
    } catch (e) {
      // Si hay error al cargar desde caché, continuamos con el stream
      print("Error al cargar liquidaciones desde caché: $e");
    }
    
    // Solo para depuración
    print("Cargadas ${_settlements.length} liquidaciones para el grupo $groupId");
    
    // Control de frecuencia: Si se cargaron datos hace menos de 30 segundos y tenemos datos,
    // no iniciamos un nuevo stream
    final now = DateTime.now();
    if (now.difference(_lastSettlementsLoadTime).inSeconds < 30 && _settlements.isNotEmpty) {
      _loadingSettlements = false;
      if (!_isDisposed) notifyListeners();
      return;
    }
    
    _lastSettlementsLoadTime = now;
    
    // Cancelar suscripción anterior si existe
    await _settlementsSubscription?.cancel();
    
    // Suscribirse a nuevos cambios
    _settlementsSubscription = _firestoreService.getSettlements(groupId).listen((settlementList) {
      if (_isDisposed) return;
      _settlements = settlementList;
      _loadingSettlements = false;
      notifyListeners();
    }, onError: (error) {
      if (_isDisposed) return;
      print("Error al cargar liquidaciones: $error");
      _loadingSettlements = false;
      notifyListeners();
    });
  }

  Future<void> addSettlement(SettlementModel settlement) async {
    await _firestoreService.addSettlement(settlement);
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    _expensesSubscription?.cancel();
    _settlementsSubscription?.cancel();
    super.dispose();
  }
  
  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
