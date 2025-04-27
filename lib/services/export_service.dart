import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import '../models/expense_model.dart';
import '../models/settlement_model.dart';

class ExportService {
  // Exporta gastos a CSV
  Future<File> exportExpensesToCsv(List<ExpenseModel> expenses, String filePath) async {
    final List<List<dynamic>> rows = [
      [
        'ID', 'Descripción', 'Monto', 'Fecha', 'Pagadores', 'Participantes', 'Categoría', 'Recurrente', 'Bloqueado'
      ],
      ...expenses.map((e) => [
        e.id,
        e.description,
        e.amount,
        e.date.toIso8601String(),
        e.payers.toString(),
        e.participantIds.join(','),
        e.category ?? '',
        e.isRecurring,
        e.isLocked
      ])
    ];
    String csv = const ListToCsvConverter().convert(rows);
    final file = File(filePath);
    return file.writeAsString(csv);
  }

  // Exporta liquidaciones a CSV
  Future<File> exportSettlementsToCsv(List<SettlementModel> settlements, String filePath) async {
    final List<List<dynamic>> rows = [
      [
        'ID', 'De', 'Para', 'Monto', 'Fecha', 'Nota', 'Estado'
      ],
      ...settlements.map((s) => [
        s.id,
        s.fromUserId,
        s.toUserId,
        s.amount,
        s.date.toIso8601String(),
        s.note ?? '',
        s.status
      ])
    ];
    String csv = const ListToCsvConverter().convert(rows);
    final file = File(filePath);
    return file.writeAsString(csv);
  }

  // Exporta gastos a JSON
  String exportExpensesToJson(List<ExpenseModel> expenses) {
    return jsonEncode(expenses.map((e) => e.toMap()).toList());
  }

  // Exporta liquidaciones a JSON
  String exportSettlementsToJson(List<SettlementModel> settlements) {
    return jsonEncode(settlements.map((s) => s.toMap()).toList());
  }
}
