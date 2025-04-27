import '../models/expense_model.dart';

class RecurrentExpenseService {
  // Genera el próximo gasto recurrente según la regla
  ExpenseModel? generateNextExpense(ExpenseModel expense) {
    if (!expense.isRecurring || expense.recurringRule == null) return null;
    DateTime nextDate;
    switch (expense.recurringRule) {
      case 'monthly':
        nextDate = DateTime(expense.date.year, expense.date.month + 1, expense.date.day);
        break;
      case 'weekly':
        nextDate = expense.date.add(Duration(days: 7));
        break;
      case 'daily':
        nextDate = expense.date.add(Duration(days: 1));
        break;
      default:
        return null;
    }
    return ExpenseModel(
      id: '', // Se asignará nuevo ID al guardar
      groupId: expense.groupId,
      description: expense.description,
      amount: expense.amount,
      date: nextDate,
      participantIds: expense.participantIds,
      payers: expense.payers,
      createdBy: expense.createdBy,
      category: expense.category,
      attachments: expense.attachments,
      splitType: expense.splitType,
      customSplits: expense.customSplits,
      isRecurring: expense.isRecurring,
      recurringRule: expense.recurringRule,
      isLocked: false,
    );
  }
}
