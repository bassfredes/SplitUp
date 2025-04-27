import '../models/expense_model.dart';
import '../models/settlement_model.dart';

class Filters {
  // Filtra gastos por descripción (case insensitive)
  static List<ExpenseModel> byDescription(List<ExpenseModel> expenses, String query) {
    return expenses.where((e) => e.description.toLowerCase().contains(query.toLowerCase())).toList();
  }

  // Filtra gastos por categoría
  static List<ExpenseModel> byCategory(List<ExpenseModel> expenses, String category) {
    return expenses.where((e) => (e.category ?? '').toLowerCase() == category.toLowerCase()).toList();
  }

  // Filtra gastos por rango de fechas
  static List<ExpenseModel> byDateRange(List<ExpenseModel> expenses, DateTime start, DateTime end) {
    return expenses.where((e) => e.date.isAfter(start) && e.date.isBefore(end)).toList();
  }

  // Filtra gastos por participante
  static List<ExpenseModel> byParticipant(List<ExpenseModel> expenses, String userId) {
    return expenses.where((e) => e.participantIds.contains(userId)).toList();
  }

  // Filtra gastos por monto mínimo y/o máximo
  static List<ExpenseModel> byAmountRange(List<ExpenseModel> expenses, {double? min, double? max}) {
    return expenses.where((e) {
      final validMin = min == null || e.amount >= min;
      final validMax = max == null || e.amount <= max;
      return validMin && validMax;
    }).toList();
  }

  // Filtra liquidaciones por usuario involucrado
  static List<SettlementModel> settlementsByUser(List<SettlementModel> settlements, String userId) {
    return settlements.where((s) => s.fromUserId == userId || s.toUserId == userId).toList();
  }
}
