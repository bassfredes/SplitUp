# SplitUp Application

SplitUp es una aplicación Flutter para gestionar gastos compartidos y dividir cuentas entre amigos, grupos y actividades. Permite crear grupos, registrar gastos, dividir montos de forma personalizada, liquidar deudas y visualizar balances en tiempo real.

## Características principales
- Registro e inicio de sesión con email y Google
- Verificación de correo electrónico
- Creación y gestión de grupos
- Invitación de participantes por email
- Registro y edición de gastos compartidos
- División de gastos personalizada (igual, porcentajes, montos, shares)
- Adjuntar imágenes y comprobantes a los gastos
- Liquidaciones y cálculo automático de deudas
- Resumen de balances por usuario y grupo
- Notificaciones locales y push (Firebase)
- Soporte multiplataforma: Android, iOS, Web, Windows, Linux, macOS

## Capturas de pantalla

### Dashboard (Web/Desktop)
![Dashboard Desktop](assets/logo/header.png)

### Dashboard (Mobile)
![Dashboard Mobile](assets/icon/splitup-logo.png)

> Puedes agregar tus propias capturas en la carpeta `assets/` para personalizar este README.

## Instalación y configuración
1. Clona el repositorio:
   ```bash
   git clone <repo-url>
   cd splitup_application
   ```
2. Instala dependencias:
   ```bash
   flutter pub get
   ```
3. Configura Firebase:
   - Agrega tus archivos `google-services.json` (Android) y `GoogleService-Info.plist` (iOS) en las carpetas correspondientes.
   - Genera `firebase_options.dart` usando FlutterFire CLI:
     ```bash
     flutterfire configure
     ```
4. Ejecuta la app:
   ```bash
   flutter run
   ```

## Estructura del proyecto
- `lib/` Código principal de la app (modelos, providers, servicios, pantallas, widgets)
- `android/`, `ios/`, `web/`, `linux/`, `windows/`, `macos/`: Plataformas soportadas
- `assets/`: Recursos gráficos (iconos, imágenes, capturas)

## Actualizaciones recientes
- Mejoras visuales en el dashboard y pantallas de grupo
- Resumen de balances actualizado automáticamente
- Visualización responsiva para mobile y desktop
- División de gastos flexible y validaciones mejoradas
- Mejoras en la experiencia de usuario y accesibilidad

## Seguridad
- No subas archivos de claves ni configuraciones sensibles a git (`.gitignore` ya los excluye)
- Configura reglas de seguridad en Firestore para proteger los datos de los usuarios y grupos

## Licencia
Este proyecto es solo para fines educativos y personales.
