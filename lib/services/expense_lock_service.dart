import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseLockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Bloquea un gasto (solo admin o aprobación unánime)
  Future<void> lockExpense(String groupId, String expenseId) async {
    await _db.collection('groups').doc(groupId)
      .collection('expenses').doc(expenseId)
      .update({'isLocked': true});
  }

  // Desbloquea un gasto (requiere lógica de aprobación unánime)
  Future<void> unlockExpense(String groupId, String expenseId) async {
    await _db.collection('groups').doc(groupId)
      .collection('expenses').doc(expenseId)
      .update({'isLocked': false});
  }

  // Verifica si un gasto está bloqueado
  Future<bool> isExpenseLocked(String groupId, String expenseId) async {
    final doc = await _db.collection('groups').doc(groupId)
      .collection('expenses').doc(expenseId).get();
    return doc.data()?['isLocked'] ?? false;
  }
}
