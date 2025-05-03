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
  {'code': 'EUR', 'label': 'Euro', 'icon': '🇪🇺'},
  {'code': 'USD', 'label': 'US Dollar', 'icon': '🇺🇸'},
  {'code': 'COP', 'label': 'Colombian Peso', 'icon': '🇨🇴'},
  {'code': 'MXN', 'label': 'Mexican Peso', 'icon': '🇲🇽'},
  {'code': 'PEN', 'label': 'Peruvian Sol', 'icon': '🇵🇪'},
  {'code': 'BRL', 'label': 'Brazilian Real', 'icon': '🇧🇷'},
  {'code': 'ARS', 'label': 'Argentinian Peso', 'icon': '🇦🇷'},
  {'code': 'UYU', 'label': 'Uruguayan Peso', 'icon': '🇺🇾'},
  {'code': 'PYG', 'label': 'Paraguayan Guarani', 'icon': '🇵🇾'},
  {'code': 'VEF', 'label': 'Venezuelan Bolívar', 'icon': '🇻🇪'},
  {'code': 'DOP', 'label': 'Dominican Peso', 'icon': '🇩🇴'},
  {'code': 'GTQ', 'label': 'Guatemalan Quetzal', 'icon': '🇬🇹'},
  {'code': 'HNL', 'label': 'Honduran Lempira', 'icon': '🇭🇳'},
  {'code': 'NIO', 'label': 'Nicaraguan Córdoba', 'icon': '🇳🇮'},
  {'code': 'CUP', 'label': 'Cuban Peso', 'icon': '🇨🇺'},
  {'code': 'CRC', 'label': 'Costa Rican Colón', 'icon': '🇨🇷'},
  {'code': 'SVC', 'label': 'Salvadoran Colón', 'icon': '🇸🇻'},
  {'code': 'BAM', 'label': 'Bosnia and Herzegovina Convertible Mark', 'icon': '🇧🇦'},
  {'code': 'BGN', 'label': 'Bulgarian Lev', 'icon': '🇧🇬'},
  {'code': 'HRK', 'label': 'Croatian Kuna', 'icon': '🇭🇷'},
  {'code': 'RON', 'label': 'Romanian Leu', 'icon': '🇷🇴'},
  {'code': 'RSD', 'label': 'Serbian Dinar', 'icon': '🇷🇸'},
  {'code': 'CZK', 'label': 'Czech Koruna', 'icon': '🇨🇿'},
  {'code': 'HUF', 'label': 'Hungarian Forint', 'icon': '🇭🇺'},
  {'code': 'PLN', 'label': 'Polish Zloty', 'icon': '🇵🇱'},
  {'code': 'SEK', 'label': 'Swedish Krona', 'icon': '🇸🇪'},
  {'code': 'NOK', 'label': 'Norwegian Krone', 'icon': '🇳🇴'},
  {'code': 'DKK', 'label': 'Danish Krone', 'icon': '🇩🇰'},
  {'code': 'CHF', 'label': 'Swiss Franc', 'icon': '🇨🇭'},
];

// Colores principales del proyecto
const kPrimaryColor = Color(0xFF159D9E);
const kAccentColor = Color(0xFFFF914D);
const kErrorColor = Color(0xFFE57373);
const kLightGrey = Color(0xFFE0E0E0);
