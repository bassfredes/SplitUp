import 'package:intl/intl.dart';

/// Formatea un monto según la moneda especificada, asegurando el símbolo al inicio.
///
/// - CLP: $1.234 (sin decimales, con puntos de miles)
/// - USD: $12.34 (con 2 decimales)
/// - EUR: €12.34 (con 2 decimales)
/// - Otras: $12.34 (con 2 decimales)
String formatCurrency(double amount, String currency) {
  final String symbol;
  final NumberFormat format;

  switch (currency) {
    case 'CLP':
      symbol = '\$';
      // Formato chileno para el número: sin decimales, con puntos como separador de miles.
      format = NumberFormat('#,##0', 'es_CL');
      break;
    case 'USD':
      symbol = '\$';
      // Formato US para el número: con 2 decimales, coma como separador de miles.
      format = NumberFormat('#,##0.00', 'en_US');
      break;
    case 'EUR':
      symbol = '€';
      // Formato europeo (ej. Alemania) para el número: con 2 decimales, punto como separador de miles.
      format = NumberFormat('#,##0.00', 'de_DE');
      break;
    default:
      symbol = '\$';
      // Formato por defecto (US) para el número.
      format = NumberFormat('#,##0.00', 'en_US');
      break;
  }

  // Construir manualmente la cadena con el símbolo al principio.
  return '$symbol${format.format(amount)}';
}

/// Formatea una fecha a 'dd MMM' (ej: '2 May').
String formatDateShort(DateTime? date) {
  if (date == null) return '';
  // Usar intl para formato localizado si es necesario, o un formato simple
  final months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
