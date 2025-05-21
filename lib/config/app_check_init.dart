import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode; // Añadido kDebugMode

Future<void> initializeAppCheck() async {
  try {
    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('6LfW0yUrAAAAAI7QFs_2qoY7KEHTQvhzIkNnLL13'),
      );
      if (kDebugMode) {
        print('Firebase App Check activated for web with reCAPTCHA v3.');
      }
    } else {
      // Para desarrollo móvil, se usa AndroidProvider.debug y AppleProvider.debug
      // En producción, esto debería ser AndroidProvider.playIntegrity y AppleProvider.deviceCheck
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
      if (kDebugMode) {
        print('Firebase App Check activated for mobile.');
      }
    }

    // Intenta obtener un token inmediatamente después de la activación para diagnóstico
    try {
      final String? token = await FirebaseAppCheck.instance.getToken(true); // true fuerza el refresco
      if (kDebugMode) {
        print('App Check token obtained inside initializeAppCheck (immediately after activate): ${token != null ? "OK (token: $token)" : "Failed or Null"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting App Check token inside initializeAppCheck: $e');
      }
    }

  } catch (e) {
    if (kDebugMode) {
      print('Error initializing Firebase App Check: $e');
    }
    // Podrías considerar relanzar el error o manejarlo de otra forma si la inicialización de App Check es crítica.
  }
}
