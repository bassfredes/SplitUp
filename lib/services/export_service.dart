import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/settlement_model.dart';
import '../models/user_model.dart';

class ExportService {
  // Exporta gastos a CSV y devuelve el contenido como String
  String exportExpensesToCsv(List<ExpenseModel> expenses, List<UserModel> users, String groupName) {
    final List<List<dynamic>> rows = [
      [
        'ID', 'Descripción', 'Monto', 'Moneda', 'Fecha', 'Pagadores (email:monto)', 'Participantes (emails)', 'Categoría', 'Recurrente', 'Bloqueado'
      ],
      ...expenses.map((e) {
        final idToEmail = {for (var u in users) u.id: u.email};
        final payersStr = e.payers.map((p) {
          final email = idToEmail[p['userId']] ?? p['userId'];
          final monto = (p['amount'] is double) ? (p['amount'] as double).toStringAsFixed(2) : p['amount'].toString();
          return '$email:$monto';
        }).join(';');
        final participantsStr = e.participantIds.map((id) => idToEmail[id] ?? id).join(';');
        return [
          e.id,
          e.description,
          e.amount.toStringAsFixed(2),
          e.currency,
          e.date.toIso8601String(),
          payersStr,
          participantsStr,
          e.category ?? '',
          e.isRecurring ? 'Sí' : 'No',
          e.isLocked ? 'Sí' : 'No'
        ];
      })
    ];
    return const ListToCsvConverter().convert(rows);
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
    return await importExpensesFromCsvContentWithValidation(content, users, groupId);
  }

  // Importa gastos desde CSV usando emails, con validaciones (por contenido String, para web)
  Future<Map<String, dynamic>> importExpensesFromCsvContentWithValidation(String content, List<UserModel> users, String groupId) async {
    final List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);

    final List<String> errors = [];
    final List<ExpenseModel> validExpenses = [];

    // Encabezados esperados
    final List<String> expectedHeaders = [
      'Descripción', 'Monto', 'Moneda', 'Fecha', 
      'Pagadores (email:monto)', 'Participantes (emails)', 
      'Categoría', 'Recurrente', 'Bloqueado'
    ];

    if (rowsAsListOfValues.isEmpty) {
      return {'expenses': [], 'errors': ['El archivo CSV está vacío.']};
    }

    final List<String> headers = rowsAsListOfValues[0].map((e) => e.toString().trim()).toList();
    if (headers.length < expectedHeaders.length) {
      errors.add('El CSV no tiene suficientes columnas. Se esperaban ${expectedHeaders.length} pero se encontraron ${headers.length}.');
      return {'expenses': [], 'errors': errors};
    }

    bool headersMatch = true;
    for (int i = 0; i < expectedHeaders.length; i++) {
      if (headers[i].toLowerCase() != expectedHeaders[i].toLowerCase()) {
        headersMatch = false;
        break;
      }
    }

    if (!headersMatch) {
      errors.add('Los encabezados del CSV no coinciden con el formato esperado. Verifique que sean: ${expectedHeaders.join(", ")}');
      return {'expenses': [], 'errors': errors};
    }
    
    final idByEmail = {for (var u in users) u.email: u.id};
    final Set<String> emailsGrupo = idByEmail.keys.toSet();

    for (int i = 1; i < rowsAsListOfValues.length; i++) {
      final row = rowsAsListOfValues[i];
      // Asegurarse de que la fila tiene suficientes celdas para evitar RangeError
      if (row.length < expectedHeaders.length) {
        errors.add('Fila ${i + 1}: Número de celdas (${row.length}) incorrecto, se esperaban ${expectedHeaders.length}.');
        continue; 
      }

      String getCell(int idx) => (idx < row.length && row[idx] != null) ? row[idx].toString().trim() : '';

      final desc = getCell(0);
      final amountStr = getCell(1);
      final currency = getCell(2);
      final dateStr = getCell(3);
      final payersStr = getCell(4);
      final participantsStr = getCell(5);
      final category = getCell(6);
      final isRecurringStr = getCell(7).toLowerCase();
      final isLockedStr = getCell(8).toLowerCase();
      
      // Validaciones
      if (desc.isEmpty) {
        errors.add('Fila ${i + 1}: Descripción vacía.');
        continue;
      }

      final double? amount = double.tryParse(amountStr.replaceAll(',', '.'));
      if (amount == null || amount <= 0) {
        errors.add('Fila ${i + 1}: Monto inválido o no positivo ($amountStr).');
        continue;
      }
      if (currency.isEmpty) {
        errors.add('Fila ${i + 1}: Moneda vacía.');
        continue;
      }
      final date = DateTime.tryParse(dateStr);
      if (date == null) {
        errors.add('Fila ${i + 1}: Fecha inválida ($dateStr).');
        continue;
      }

      // Pagadores
      final payers = <Map<String, dynamic>>[];
      bool payersValid = true;
      if (payersStr.isEmpty) {
        errors.add('Fila ${i + 1}: Pagadores vacío.');
        continue;
      }
      double totalPaid = 0;
      for (final p in payersStr.split(';')) {
        final parts = p.split(':');
        if (parts.length != 2) {
          errors.add('Fila ${i + 1}: Formato de pagador inválido ($p). Debe ser email:monto.');
          payersValid = false;
          break;
        }
        final email = parts[0].trim();
        final montoStr = parts[1].trim();
        final double? monto = double.tryParse(montoStr.replaceAll(',', '.'));

        if (!emailsGrupo.contains(email)) {
          errors.add('Fila ${i + 1}: Pagador $email no pertenece al grupo.');
          payersValid = false;
        }
        if (monto == null || monto <= 0) {
          errors.add('Fila ${i + 1}: Monto de pagador inválido ($p).');
          payersValid = false;
        }
        if (payersValid) {
          final userId = idByEmail[email] ?? email; // Usar email como fallback si no se encuentra ID (aunque no debería pasar si emailsGrupo lo contiene)
          payers.add({'userId': userId, 'amount': monto});
          totalPaid += monto!;
        }
      }
      if (!payersValid) {
        continue;
      }
      // Verificar que el total pagado coincida con el monto del gasto
      if ((totalPaid - amount).abs() > 0.01) { // Usar una pequeña tolerancia para comparaciones de doubles
          errors.add('Fila ${i + 1}: La suma de los montos de los pagadores (${totalPaid.toStringAsFixed(2)}) no coincide con el monto del gasto (${amount.toStringAsFixed(2)}).');
          continue;
      }

      // Participantes
      if (participantsStr.isEmpty) {
        errors.add('Fila ${i + 1}: Participantes vacío.');
        continue;
      }
      final participantIds = <String>[];
      bool participantsValid = true;
      for (final emailRaw in participantsStr.split(';')) {
        final email = emailRaw.trim();
        if (!emailsGrupo.contains(email)) {
          errors.add('Fila ${i + 1}: Participante $email no pertenece al grupo.');
          participantsValid = false;
        } else {
          participantIds.add(idByEmail[email]!);
        }
      }
      if (!participantsValid) {
        continue;
      }
      if (participantIds.isEmpty) {
          errors.add('Fila ${i + 1}: La lista de participantes no puede estar vacía después del procesamiento.');
          continue;
      }

      final bool isRecurring = isRecurringStr == 'sí' || isRecurringStr == 'si' || isRecurringStr == 'true';
      final bool isLocked = isLockedStr == 'sí' || isLockedStr == 'si' || isLockedStr == 'true';
      
      validExpenses.add(ExpenseModel(
        id: FirebaseFirestore.instance.collection('temp').doc().id, // ID temporal
        groupId: groupId,
        description: desc,
        amount: amount,
        date: date,
        participantIds: participantIds,
        payers: payers,
        createdBy: '', // Se debería setear el ID del usuario actual al guardar
        category: category.isNotEmpty ? category : null,
        attachments: null,
        splitType: 'equal', // Asumir división igualitaria para importación simple
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
