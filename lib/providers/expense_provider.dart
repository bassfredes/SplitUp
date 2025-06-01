import 'dart:async';
import 'dart:convert'; // Added for jsonEncode and jsonDecode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/settlement_model.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart'; // Assuming CacheService is here

class ExpenseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final CacheService _cacheService = CacheService(); // Added CacheService instance
  List<ExpenseModel> _expenses = [];
  List<SettlementModel> _settlements = [];
  bool _loadingExpenses = false;
  bool _loadingSettlements = false;
  bool _isDisposed = false;
  String? _currentGroupId;

  // Nuevas variables para paginación de gastos
  DocumentSnapshot? _lastExpenseDocument;
  bool _hasMoreExpenses = true;
  final int _pageSize = 15; // Tamaño de página para gastos
  bool _loadingMoreExpenses = false;
  int _totalExpensesCount = 0; // Nueva variable para el conteo total

  StreamSubscription? _expensesSubscription;
  StreamSubscription? _settlementsSubscription;

  List<ExpenseModel> get expenses => _expenses;
  List<SettlementModel> get settlements => _settlements;
  bool get loadingExpenses => _loadingExpenses;
  bool get loadingSettlements => _loadingSettlements;
  String? get currentGroupId => _currentGroupId;

  // Nuevos getters para paginación
  bool get hasMoreExpenses => _hasMoreExpenses;
  bool get loadingMoreExpenses => _loadingMoreExpenses;

  // Nuevo getter para el total de páginas
  int get totalPages => (_totalExpensesCount / _pageSize).ceil();

  Future<void> loadExpenses(String groupId, {bool forceRefresh = false}) async {
    if (_loadingExpenses && !forceRefresh && groupId == _currentGroupId) return;

    if (forceRefresh || _currentGroupId != groupId) {
      _expenses = [];
      _lastExpenseDocument = null;
      _hasMoreExpenses = true;
      _totalExpensesCount = 0; // Resetear el conteo total
      // Cargar el conteo total cuando el grupo cambia o se fuerza la actualización
      await fetchTotalExpensesCount(groupId); 
    }
    
    _currentGroupId = groupId;
    _loadingExpenses = true;
    if (!_isDisposed) notifyListeners();

    // --- Cache Logic Start ---
    if (!forceRefresh) {
      final cacheKey = 'group_expenses_${groupId}_page_0';
      final cachedPayload = _cacheService.getData(cacheKey) as Map<String, dynamic>?;

      if (cachedPayload != null) {
        _expenses = (jsonDecode(cachedPayload['expenses'] as String) as List<dynamic>)
            .map((map) => ExpenseModel.fromMap(map as Map<String, dynamic>, map['id'] as String))
            .toList();
        final String? lastDocPath = cachedPayload['lastDocPath'] as String?;
        if (lastDocPath != null) {
          _lastExpenseDocument = await _firestoreService.getDocumentSnapshot(lastDocPath);
        } else {
          _lastExpenseDocument = null;
        }
        _hasMoreExpenses = cachedPayload['hasMore'] as bool;
        _loadingExpenses = false;
        if (!_isDisposed) notifyListeners();
        print("ExpenseProvider: Primera página de gastos cargada desde CACHÉ para el grupo $groupId.");
        return;
      }
    }
    // --- Cache Logic End ---

    try {
      final expenseList = await _firestoreService.getExpensesPaginated(
        groupId,
        _pageSize,
        null, // Para la primera página, lastDocument es null
      );

      if (_isDisposed) return;

      _expenses = expenseList;
      if (expenseList.isNotEmpty) {
        _lastExpenseDocument = await _firestoreService.getDocumentSnapshot(
          'groups/$groupId/expenses/${expenseList.last.id}'
        );
      }
      _hasMoreExpenses = expenseList.length == _pageSize;
      
      // --- Cache Storing Logic Start ---
      final cacheKey = 'group_expenses_${groupId}_page_0';
      final pageDataToCache = {
        'expenses': jsonEncode(_expenses.map((e) => e.toMap(forCache: true)).toList()),
        'lastDocPath': _lastExpenseDocument?.reference.path,
        'hasMore': _hasMoreExpenses,
      };
      await _cacheService.setData(cacheKey, pageDataToCache);
      print("ExpenseProvider: Primera página de gastos guardada en CACHÉ para el grupo $groupId.");
      // --- Cache Storing Logic End ---

      print("ExpenseProvider: Primera página de gastos cargada para el grupo $groupId. Hay más: $_hasMoreExpenses");

    } catch (e) {
      if (_isDisposed) return;
      print("Error al cargar la primera página de gastos para el grupo $groupId: $e");
      _hasMoreExpenses = false; // Asumir que no hay más si hay error
    } finally {
      if (!_isDisposed) {
        _loadingExpenses = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchTotalExpensesCount(String groupId) async {
    try {
      _totalExpensesCount = await _firestoreService.getExpensesCount(groupId);
      if (!_isDisposed) notifyListeners();
      print("ExpenseProvider: Conteo total de gastos para el grupo $groupId: $_totalExpensesCount");
    } catch (e) {
      if (_isDisposed) return;
      print("Error al obtener el conteo total de gastos para el grupo $groupId: $e");
      // Opcionalmente, manejar el error, por ejemplo, estableciendo un valor por defecto o reintentando.
    }
  }

  Future<void> loadMoreExpenses(String groupId) async {
    if (_loadingMoreExpenses || _loadingExpenses || !_hasMoreExpenses || _currentGroupId != groupId) {
      print("ExpenseProvider: No se cargan más gastos. LoadingMore: $_loadingMoreExpenses, LoadingInitial: $_loadingExpenses, HasMore: $_hasMoreExpenses, GroupId: $groupId (Current: $_currentGroupId)");
      return;
    }

    _loadingMoreExpenses = true;
    if (!_isDisposed) notifyListeners();

    // --- Cache Logic Start ---
    final String? previousLastDocId = _lastExpenseDocument?.id;
    if (previousLastDocId == null || previousLastDocId.isEmpty) {
      _loadingMoreExpenses = false;
      if (!_isDisposed) notifyListeners();
      print("ExpenseProvider: Error - loadMoreExpenses llamado sin un lastExpenseDocument válido.");
      return;
    }

    final cacheKey = 'group_expenses_${groupId}_after_${previousLastDocId}';
    final cachedPayload = _cacheService.getData(cacheKey) as Map<String, dynamic>?;

    if (cachedPayload != null) {
      final List<ExpenseModel> newExpenses = (jsonDecode(cachedPayload['expenses'] as String) as List<dynamic>)
          .map((map) => ExpenseModel.fromMap(map as Map<String, dynamic>, map['id'] as String))
          .toList();
      _expenses.addAll(newExpenses);
      final String? lastDocPath = cachedPayload['lastDocPath'] as String?;
      if (lastDocPath != null) {
        _lastExpenseDocument = await _firestoreService.getDocumentSnapshot(lastDocPath);
      } else {
        _lastExpenseDocument = null;
      }
      _hasMoreExpenses = cachedPayload['hasMore'] as bool;
      _loadingMoreExpenses = false;
      if (!_isDisposed) notifyListeners();
      print("ExpenseProvider: Siguiente página de gastos cargada desde CACHÉ para el grupo $groupId after $previousLastDocId.");
      return;
    }
    // --- Cache Logic End ---

    try {
      print("ExpenseProvider: Cargando más gastos para el grupo $groupId después de ${_lastExpenseDocument?.id}");
      final expenseList = await _firestoreService.getExpensesPaginated(
        groupId,
        _pageSize,
        _lastExpenseDocument,
      );

      if (_isDisposed) return;

      if (expenseList.isNotEmpty) {
        _lastExpenseDocument = await _firestoreService.getDocumentSnapshot(
          'groups/$groupId/expenses/${expenseList.last.id}'
        );
         _expenses.addAll(expenseList); // Add new expenses to the list
      } else {
        // No new expenses were fetched, which might mean _lastExpenseDocument should not change,
        // or it's the definitive end of the list.
      }

      _hasMoreExpenses = expenseList.length == _pageSize;

      // --- Cache Storing Logic Start ---
      final cacheKeyForStorage = 'group_expenses_${groupId}_after_${previousLastDocId}';
      final pageDataToCache = {
        'expenses': jsonEncode(expenseList.map((e) => e.toMap(forCache: true)).toList()),
        'lastDocPath': _lastExpenseDocument?.reference.path,
        'hasMore': _hasMoreExpenses,
      };
      await _cacheService.setData(cacheKeyForStorage, pageDataToCache);
      print("ExpenseProvider: Siguiente página de gastos guardada en CACHÉ para el grupo $groupId.");
      // --- Cache Storing Logic End ---

      print("ExpenseProvider: Siguiente página de gastos cargada. Total: ${_expenses.length}. Hay más: $_hasMoreExpenses");

    } catch (e) {
      if (_isDisposed) return;
      print("Error al cargar más gastos para el grupo $groupId: $e");
    } finally {
      if (!_isDisposed) {
        _loadingMoreExpenses = false;
        notifyListeners();
      }
    }
  }

  Future<void> addExpense(ExpenseModel expense) async {
    try {
      await _firestoreService.addExpense(expense);
      // --- Cache Invalidation Start ---
      await _cacheService.removeKeysWithPattern('group_expenses_${expense.groupId}_');
      print("ExpenseProvider: Caché de paginación invalidada para el grupo ${expense.groupId} debido a nuevo gasto.");
      // --- Cache Invalidation End ---
      if (_currentGroupId == expense.groupId) {
        await loadExpenses(expense.groupId, forceRefresh: true);
      }
    } catch (e) {
      print("Error al añadir gasto: $e");
    }
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    try {
      await _firestoreService.updateExpense(expense);
      await _cacheService.removeKeysWithPattern('group_expenses_${expense.groupId}_');
      print("ExpenseProvider: Caché de paginación invalidada para el grupo ${expense.groupId} debido a actualización de gasto.");
      // Solo recargar si el grupo actual es el afectado.
      if (_currentGroupId == expense.groupId) {
        await loadExpenses(expense.groupId, forceRefresh: true);
      }
    } catch (e) {
      print("Error al actualizar gasto: $e");
      // Considera re-lanzar el error o manejarlo de forma más específica si es necesario
    }
  }

  Future<void> loadSettlements(String groupId, {bool forceRefresh = false}) async {
    if (_loadingSettlements && !forceRefresh && groupId == _currentGroupId) return;

    if (_currentGroupId != groupId) {
        _settlements = [];
        await _settlementsSubscription?.cancel();
        _settlementsSubscription = null;
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
