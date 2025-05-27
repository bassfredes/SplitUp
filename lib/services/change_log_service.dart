import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/change_log_model.dart';

class ChangeLogService {
  final FirebaseFirestore _db;

  // Constructor accepting a FirebaseFirestore instance
  ChangeLogService([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  // Registrar un cambio
  Future<void> logChange(ChangeLogModel log) async {
    await _db.collection('change_logs').add(log.toMap());
  }

  // Obtener historial por entidad
  Stream<List<ChangeLogModel>> getLogsByEntity(String entityType, String entityId) {
    return _db
        .collection('change_logs')
        .where('entityType', isEqualTo: entityType)
        .where('entityId', isEqualTo: entityId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChangeLogModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Obtener historial por usuario
  Stream<List<ChangeLogModel>> getLogsByUser(String userId) {
    return _db
        .collection('change_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChangeLogModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
