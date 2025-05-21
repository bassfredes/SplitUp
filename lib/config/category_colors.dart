import 'package:flutter/material.dart';

// Mapa de colores para las categorías de gastos
Map<String, Color> categoryColors = {
  'food': const Color(0xFF4CAF50), // Green
  'fast food': const Color(0xFF8BC34A), // Light green
  'transport': const Color(0xFF2196F3), // Blue
  'public transport': const Color(0xFF03A9F4), // Light blue
  'bus': const Color(0xFF00BCD4), // Cyan
  'taxi': const Color(0xFF0097A7), // Dark cyan
  'home': const Color(0xFFFF9800), // Orange
  'house': const Color(0xFFFF9800), // Orange (synonym)
  'leisure': const Color(0xFF9C27B0), // Purple
  'entertainment': const Color(0xFFE91E63), // Pink
  'travel': const Color(0xFF3F51B5), // Indigo
  'health': const Color(0xFFF44336), // Red
  'shopping': const Color(0xFFFF5722), // Dark orange
  'other': const Color(0xFF607D8B), // Blue Grey
};

// Obtener un color para una categoría, si no existe, generar uno basado en el hash del nombre
Color getCategoryColor(String category) {
  // Buscar el color exacto (en inglés)
  final color = categoryColors[category.toLowerCase()];
  if (color != null) return color;
  // Si no hay un color definido, generar uno basado en el hash del nombre
  final hash = category.hashCode;
  return Color(0xFF000000 + (hash & 0x00FFFFFF)).withAlpha((0.7 * 255).round());
}
