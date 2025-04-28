import 'package:flutter/material.dart';

// Categorías compatibles con los gastos
const List<Map<String, dynamic>> kExpenseCategories = [
  {'key': 'comida', 'label': 'Comida Rápida', 'icon': 'fastfood'},
  {'key': 'food', 'label': 'Comida', 'icon': 'restaurant'},
  {'key': 'transporte', 'label': 'Transporte', 'icon': 'directions_car'},
  {'key': 'transporte público', 'label': 'Transporte público', 'icon': 'directions_transit'},
  {'key': 'bus', 'label': 'Bus', 'icon': 'directions_bus'},
  {'key': 'taxi', 'label': 'Taxi', 'icon': 'directions_bus'},
  {'key': 'hogar', 'label': 'Hogar', 'icon': 'home'},
  {'key': 'casa', 'label': 'Casa', 'icon': 'home'},
  {'key': 'ocio', 'label': 'Ocio', 'icon': 'local_play'},
  {'key': 'entretenimiento', 'label': 'Entretenimiento', 'icon': 'celebration'},
  {'key': 'viaje', 'label': 'Viaje', 'icon': 'flight'},
  {'key': 'salud', 'label': 'Salud', 'icon': 'local_hospital'},
  {'key': 'compras', 'label': 'Compras', 'icon': 'shopping_cart'},
  {'key': 'otros', 'label': 'Otros', 'icon': 'category'},
];

// Monedas compatibles con la app
const List<Map<String, String>> kCurrencies = [
  {'code': 'CLP', 'label': 'Peso Chileno', 'icon': '🇨🇱'},
  {'code': 'USD', 'label': 'Dólar estadounidense', 'icon': '🇺🇸'},
  {'code': 'EUR', 'label': 'Euro', 'icon': '🇪🇺'},
  // Puedes agregar más monedas aquí si lo necesitas
];

// Colores principales del proyecto
const kPrimaryColor = Color(0xFF159D9E);
const kAccentColor = Color(0xFFFF914D);
const kErrorColor = Color(0xFFE57373);
const kLightGrey = Color(0xFFE0E0E0);
