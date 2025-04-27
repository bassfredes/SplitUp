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

  List<ExpenseModel> get expenses => _expenses;
  List<SettlementModel> get settlements => _settlements;
  bool get loadingExpenses => _loadingExpenses;
  bool get loadingSettlements => _loadingSettlements;

  Future<void> loadExpenses(String groupId) async {
    _loadingExpenses = true;
    notifyListeners();
    _firestoreService.getExpenses(groupId).listen((expenseList) {
      _expenses = expenseList;
      _loadingExpenses = false;
      notifyListeners();
    });
  }

  Future<void> addExpense(ExpenseModel expense) async {
    await _firestoreService.addExpense(expense);
  }

  Future<void> loadSettlements(String groupId) async {
    _loadingSettlements = true;
    notifyListeners();
    _firestoreService.getSettlements(groupId).listen((settlementList) {
      _settlements = settlementList;
      _loadingSettlements = false;
      notifyListeners();
    });
  }

  Future<void> addSettlement(SettlementModel settlement) async {
    await _firestoreService.addSettlement(settlement);
  }
}
