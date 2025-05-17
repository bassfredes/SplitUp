import 'package:flutter/material.dart';

// Categorías compatibles con los gastos
const List<Map<String, dynamic>> kExpenseCategories = [
  {'key': 'food', 'label': 'Food', 'icon': 'restaurant'},
  {'key': 'fast food', 'label': 'Fast Food', 'icon': 'fastfood'},
  {'key': 'transport', 'label': 'Transport', 'icon': 'directions_car'},
  {'key': 'public transport', 'label': 'Public Transport', 'icon': 'directions_transit'},
  {'key': 'bus', 'label': 'Bus', 'icon': 'directions_bus'},
  {'key': 'taxi', 'label': 'Taxi', 'icon': 'directions_bus'},
  {'key': 'home', 'label': 'Home', 'icon': 'home'},
  {'key': 'house', 'label': 'House', 'icon': 'home'},
  {'key': 'leisure', 'label': 'Leisure', 'icon': 'local_play'},
  {'key': 'entertainment', 'label': 'Entertainment', 'icon': 'celebration'},
  {'key': 'travel', 'label': 'Travel', 'icon': 'flight'},
  {'key': 'health', 'label': 'Health', 'icon': 'local_hospital'},
  {'key': 'shopping', 'label': 'Shopping', 'icon': 'shopping_cart'},
  {'key': 'other', 'label': 'Other', 'icon': 'category'},
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
