import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import '../models/settlement_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Grupos
  Future<void> createGroup(GroupModel group) async {
    await _db.collection('groups').doc(group.id).set(group.toMap());
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
  }

  Stream<GroupModel> getGroup(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().map(
      (doc) => GroupModel.fromMap(doc.data()!, doc.id),
    );
  }

  Stream<List<GroupModel>> getUserGroups(String userId) {
    if (userId.isEmpty) {
      // Retorna un stream vacío si el userId es inválido
      return Stream.value([]);
    }
    return _db.collection('groups')
      .where('participantIds', arrayContains: userId)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => GroupModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Gastos
  Future<void> addExpense(ExpenseModel expense) async {
    await _db.collection('groups').doc(expense.groupId)
      .collection('expenses').doc(expense.id).set(expense.toMap());
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _db
        .collection('groups')
        .doc(expense.groupId)
        .collection('expenses')
        .doc(expense.id)
        .update(expense.toMap());
  }

  Stream<List<ExpenseModel>> getExpenses(String groupId) {
    return _db.collection('groups').doc(groupId)
      .collection('expenses')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Elimina un participante de todos los gastos del grupo y ajusta los montos
  Future<void> removeParticipantFromExpenses(String groupId, String userId) async {
    final expensesSnap = await _db.collection('groups').doc(groupId).collection('expenses').get();
    for (final doc in expensesSnap.docs) {
      final expense = ExpenseModel.fromMap(doc.data(), doc.id);
      if (!expense.participantIds.contains(userId)) continue;
      // Quitar participante
      final newParticipantIds = List<String>.from(expense.participantIds)..remove(userId);
      List<Map<String, dynamic>>? newCustomSplits;
      if (expense.customSplits != null) {
        newCustomSplits = expense.customSplits!.where((split) => split['userId'] != userId).toList();
      }
      // Recalcular montos si es división igualitaria
      double newAmount = expense.amount;
      if (expense.customSplits == null && newParticipantIds.isNotEmpty) {
        newAmount = expense.amount * newParticipantIds.length / expense.participantIds.length;
      }
      await _db.collection('groups').doc(groupId).collection('expenses').doc(expense.id).update({
        'participantIds': newParticipantIds,
        'customSplits': newCustomSplits,
        'amount': newAmount,
      });
    }
  }

  // Liquidaciones
  Future<void> addSettlement(SettlementModel settlement) async {
    await _db.collection('groups').doc(settlement.groupId)
      .collection('settlements').doc(settlement.id).set(settlement.toMap());
  }

  Stream<List<SettlementModel>> getSettlements(String groupId) {
    return _db.collection('groups').doc(groupId)
      .collection('settlements')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => SettlementModel.fromMap(doc.data(), doc.id)).toList());
  }

  // Limpia todos los gastos y liquidaciones de un grupo (antes de eliminarlo)
  Future<void> cleanGroupExpensesAndSettlements(String groupId) async {
    final expensesSnap = await _db.collection('groups').doc(groupId).collection('expenses').get();
    for (final doc in expensesSnap.docs) {
      await doc.reference.delete();
    }
    final settlementsSnap = await _db.collection('groups').doc(groupId).collection('settlements').get();
    for (final doc in settlementsSnap.docs) {
      await doc.reference.delete();
    }
  }
}
