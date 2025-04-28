import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../models/expense_model.dart';
import '../models/settlement_model.dart';
import '../models/user_model.dart';

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

  // Exporta gastos a XLSX usando emails
  Future<File> exportExpensesToXlsx(List<ExpenseModel> expenses, List<UserModel> users, String filePath) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    // Encabezados
    sheet.getRangeByName('A1').setText('Descripción');
    sheet.getRangeByName('B1').setText('Monto');
    sheet.getRangeByName('C1').setText('Moneda');
    sheet.getRangeByName('D1').setText('Fecha');
    sheet.getRangeByName('E1').setText('Pagadores (email:monto)');
    sheet.getRangeByName('F1').setText('Participantes (emails)');
    sheet.getRangeByName('G1').setText('Categoría');
    sheet.getRangeByName('H1').setText('Recurrente');
    sheet.getRangeByName('I1').setText('Bloqueado');
    // Map de userId a email
    final idToEmail = {for (var u in users) u.id: u.email};
    for (int i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      final row = i + 2;
      sheet.getRangeByName('A$row').setText(e.description);
      sheet.getRangeByName('B$row').setNumber(e.amount);
      sheet.getRangeByName('C$row').setText(e.currency);
      sheet.getRangeByName('D$row').setText(e.date.toIso8601String());
      // Pagadores: email:monto separados por ;
      final payersStr = e.payers.map((p) {
        final email = idToEmail[p['userId']] ?? p['userId'];
        final monto = (p['amount'] is double) ? (p['amount'] as double).toInt() : p['amount'];
        return '$email:$monto';
      }).join(';');
      sheet.getRangeByName('E$row').setText(payersStr);
      // Participantes: emails separados por ;
      final participantsStr = e.participantIds.map((id) => idToEmail[id] ?? id).join(';');
      sheet.getRangeByName('F$row').setText(participantsStr);
      sheet.getRangeByName('G$row').setText(e.category ?? '');
      sheet.getRangeByName('H$row').setText(e.isRecurring ? 'Sí' : 'No');
      sheet.getRangeByName('I$row').setText(e.isLocked ? 'Sí' : 'No');
    }
    final bytes = workbook.saveAsStream();
    workbook.dispose();
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  // Importa gastos desde CSV usando emails, con validaciones
  Future<Map<String, dynamic>> importExpensesFromCsvWithValidation(File file, List<UserModel> users, String groupId) async {
    final content = await file.readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty || rows[0].length < 9) {
      return {'expenses': [], 'errors': ['El archivo CSV no tiene el formato esperado.']};
    }
    final idByEmail = {for (var u in users) u.email: u.id};
    final Set<String> emailsGrupo = idByEmail.keys.toSet();
    final List<ExpenseModel> validExpenses = [];
    final List<String> errors = [];
    for (int row = 1; row < rows.length; row++) {
      final cells = rows[row];
      String getCell(int idx) => (idx < cells.length && cells[idx] != null) ? cells[idx].toString().trim() : '';
      final desc = getCell(0);
      final amountStr = getCell(1);
      final currency = getCell(2);
      final dateStr = getCell(3);
      final payersStr = getCell(4);
      final participantsStr = getCell(5);
      final category = getCell(6);
      final isRecurring = getCell(7) == 'Sí';
      final isLocked = getCell(8) == 'Sí';
      // Validaciones
      if (desc.isEmpty) {
        errors.add('Fila ${row + 1}: Descripción vacía.');
        continue;
      }
      final amount = int.tryParse(amountStr.replaceAll('.', '').replaceAll(',', ''))?.toDouble();
      if (amount == null || amount <= 0) {
        errors.add('Fila ${row + 1}: Monto inválido o no positivo.');
        continue;
      }
      if (currency.isEmpty) {
        errors.add('Fila ${row + 1}: Moneda vacía.');
        continue;
      }
      final date = DateTime.tryParse(dateStr);
      if (date == null) {
        errors.add('Fila ${row + 1}: Fecha inválida.');
        continue;
      }
      // Pagadores
      final payers = <Map<String, dynamic>>[];
      bool payersValid = true;
      if (payersStr.isEmpty) {
        errors.add('Fila ${row + 1}: Pagadores vacío.');
        continue;
      }
      for (final p in payersStr.split(';')) {
        final parts = p.split(':');
        if (parts.length != 2) {
          errors.add('Fila ${row + 1}: Formato de pagador inválido ($p).');
          payersValid = false;
          break;
        }
        final email = parts[0];
        final monto = int.tryParse(parts[1].replaceAll('.', '').replaceAll(',', ''));
        if (!emailsGrupo.contains(email)) {
          errors.add('Fila ${row + 1}: Pagador $email no pertenece al grupo.');
          payersValid = false;
        }
        if (monto == null || monto <= 0) {
          errors.add('Fila ${row + 1}: Monto de pagador inválido ($p).');
          payersValid = false;
        }
        final userId = idByEmail[email] ?? email;
        payers.add({'userId': userId, 'amount': monto?.toDouble() ?? 0.0});
      }
      if (!payersValid) {
        continue;
      }
      // Participantes
      if (participantsStr.isEmpty) {
        errors.add('Fila ${row + 1}: Participantes vacío.');
        continue;
      }
      final participantIds = <String>[];
      bool participantsValid = true;
      for (final email in participantsStr.split(';')) {
        if (!emailsGrupo.contains(email)) {
          errors.add('Fila ${row + 1}: Participante $email no pertenece al grupo.');
          participantsValid = false;
        } else {
          participantIds.add(idByEmail[email]!);
        }
      }
      if (!participantsValid) {
        continue;
      }
      validExpenses.add(ExpenseModel(
        id: '',
        groupId: groupId,
        description: desc,
        amount: amount,
        date: date,
        participantIds: participantIds,
        payers: payers,
        createdBy: '',
        category: category,
        attachments: null,
        splitType: 'equal',
        customSplits: null,
        isRecurring: isRecurring,
        recurringRule: null,
        isLocked: isLocked,
        currency: currency,
      ));
    }
    return {'expenses': validExpenses, 'errors': errors};
  }

  // Importa gastos desde CSV usando emails, con validaciones (por contenido String, para web)
  Future<Map<String, dynamic>> importExpensesFromCsvContentWithValidation(String content, List<UserModel> users, String groupId) async {
    final rows = const CsvToListConverter(eol: '\n').convert(content);
    if (rows.isEmpty || rows[0].length < 9) {
      return {'expenses': [], 'errors': ['El archivo CSV no tiene el formato esperado.']};
    }
    final idByEmail = {for (var u in users) u.email: u.id};
    final Set<String> emailsGrupo = idByEmail.keys.toSet();
    final List<ExpenseModel> validExpenses = [];
    final List<String> errors = [];
    for (int row = 1; row < rows.length; row++) {
      final cells = rows[row];
      String getCell(int idx) => (idx < cells.length && cells[idx] != null) ? cells[idx].toString().trim() : '';
      final desc = getCell(0);
      final amountStr = getCell(1);
      final currency = getCell(2);
      final dateStr = getCell(3);
      final payersStr = getCell(4);
      final participantsStr = getCell(5);
      final category = getCell(6);
      final isRecurring = getCell(7) == 'Sí';
      final isLocked = getCell(8) == 'Sí';
      // Validaciones
      if (desc.isEmpty) {
        errors.add('Fila ${row + 1}: Descripción vacía.');
        continue;
      }
      final amount = int.tryParse(amountStr.replaceAll('.', '').replaceAll(',', ''))?.toDouble();
      if (amount == null || amount <= 0) {
        errors.add('Fila ${row + 1}: Monto inválido o no positivo.');
        continue;
      }
      if (currency.isEmpty) {
        errors.add('Fila ${row + 1}: Moneda vacía.');
        continue;
      }
      final date = DateTime.tryParse(dateStr);
      if (date == null) {
        errors.add('Fila ${row + 1}: Fecha inválida.');
        continue;
      }
      // Pagadores
      final payers = <Map<String, dynamic>>[];
      bool payersValid = true;
      if (payersStr.isEmpty) {
        errors.add('Fila ${row + 1}: Pagadores vacío.');
        continue;
      }
      for (final p in payersStr.split(';')) {
        final parts = p.split(':');
        if (parts.length != 2) {
          errors.add('Fila ${row + 1}: Formato de pagador inválido ($p).');
          payersValid = false;
          break;
        }
        final email = parts[0];
        final monto = int.tryParse(parts[1].replaceAll('.', '').replaceAll(',', ''));
        if (!emailsGrupo.contains(email)) {
          errors.add('Fila ${row + 1}: Pagador $email no pertenece al grupo.');
          payersValid = false;
        }
        if (monto == null || monto <= 0) {
          errors.add('Fila ${row + 1}: Monto de pagador inválido ($p).');
          payersValid = false;
        }
        final userId = idByEmail[email] ?? email;
        payers.add({'userId': userId, 'amount': monto?.toDouble() ?? 0.0});
      }
      if (!payersValid) {
        continue;
      }
      // Participantes
      if (participantsStr.isEmpty) {
        errors.add('Fila ${row + 1}: Participantes vacío.');
        continue;
      }
      final participantIds = <String>[];
      bool participantsValid = true;
      for (final email in participantsStr.split(';')) {
        if (!emailsGrupo.contains(email)) {
          errors.add('Fila ${row + 1}: Participante $email no pertenece al grupo.');
          participantsValid = false;
        } else {
          participantIds.add(idByEmail[email]!);
        }
      }
      if (!participantsValid) {
        continue;
      }
      validExpenses.add(ExpenseModel(
        id: '',
        groupId: groupId,
        description: desc,
        amount: amount,
        date: date,
        participantIds: participantIds,
        payers: payers,
        createdBy: '',
        category: category,
        attachments: null,
        splitType: 'equal',
        customSplits: null,
        isRecurring: isRecurring,
        recurringRule: null,
        isLocked: isLocked,
        currency: currency,
      ));
    }
    return {'expenses': validExpenses, 'errors': errors};
  }

  // Genera un archivo CSV de ejemplo para importación de gastos
  Future<File> generateSampleImportCsv(String filePath, List<UserModel> users) async {
    final List<List<dynamic>> rows = [
      [
        'Descripción', 'Monto', 'Moneda', 'Fecha', 'Pagadores (email:monto)', 'Participantes (emails)', 'Categoría', 'Recurrente', 'Bloqueado'
      ],
      [
        'Ejemplo de gasto',
        '10000',
        'CLP',
        '2025-04-27',
        users.isNotEmpty ? '${users.first.email}:10000' : 'correo@ejemplo.com:10000',
        users.isNotEmpty ? users.map((u) => u.email).join(';') : 'correo@ejemplo.com',
        'Comida',
        'No',
        'No'
      ]
    ];
    String csv = const ListToCsvConverter().convert(rows);
    const bom = '\uFEFF';
    final file = File(filePath);
    return file.writeAsString(bom + csv, encoding: utf8);
  }
}
