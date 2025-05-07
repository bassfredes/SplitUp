# Blueprint de Arquitectura - SplitUp Application

## 1. Descripción General
SplitUp es una aplicación Flutter multiplataforma para la gestión de gastos compartidos, permitiendo a los usuarios crear grupos, registrar gastos, dividir cuentas y liquidar deudas entre participantes. Utiliza Firebase como backend para autenticación, base de datos y almacenamiento.

## 2. Estructura de Carpetas
- **lib/**: Código principal de la app.
  - **models/**: Modelos de datos (User, Group, Expense, Settlement, etc).
  - **providers/**: Providers para gestión de estado (AuthProvider, GroupProvider, etc).
  - **services/**: Servicios para acceso a datos y lógica de negocio (FirestoreService, DebtCalculatorService, etc).
  - **screens/**: Pantallas principales de la app (Dashboard, GroupDetail, ExpenseDetail, etc).
  - **widgets/**: Widgets reutilizables y componentes UI.
  - **config/**: Configuración global y constantes.
  - **utils/**: Utilidades y helpers (formatters, validadores, etc).
- **assets/**: Recursos gráficos (iconos, imágenes).
- **android/**, **ios/**, **web/**, **linux/**, **windows/**, **macos/**: Archivos específicos de cada plataforma.

## 3. Arquitectura de la Aplicación
### 3.1. Patrón de Arquitectura
- **MVVM (Model-View-ViewModel) + Provider**
  - **Modelos**: Representan la estructura de los datos (UserModel, GroupModel, ExpenseModel, etc).
  - **Providers**: Gestionan el estado y la lógica de negocio, exponen datos y métodos a la UI usando Provider.
  - **Vistas (Screens/Widgets)**: Consumen los providers y muestran la UI reactiva.

### 3.2. Flujo de Datos
- **Autenticación**: Firebase Auth (email, Google). El estado de usuario se gestiona en AuthProvider.
- **Datos**: Firestore como base de datos en tiempo real. FirestoreService abstrae el acceso a colecciones y documentos.
- **Estado**: Provider para inyección y escucha reactiva de cambios de estado en toda la app.
- **Notificaciones**: Locales y push (Firebase Messaging, si está habilitado).

### 3.3. Principales Entidades
- **UserModel**: Usuario de la app.
- **GroupModel**: Grupo de gastos compartidos.
- **ExpenseModel**: Gasto registrado en un grupo.
- **SettlementModel**: Liquidación de deudas entre usuarios.

## 4. Principales Flujos de Usuario
- **Registro/Inicio de sesión**: Autenticación y creación de usuario en Firestore.
- **Dashboard**: Muestra resumen de balances y lista de grupos.
- **Detalle de Grupo**: Lista de gastos, participantes, balance y liquidaciones.
- **Agregar/Editar Gasto**: Formulario avanzado con división personalizada y adjuntos.
- **Detalle de Gasto**: Visualización de participantes, pagadores y archivos adjuntos.
- **Liquidaciones**: Registro y visualización de pagos entre usuarios.

## 5. Integraciones y Servicios
- **Firebase Auth**: Autenticación de usuarios.
- **Cloud Firestore**: Almacenamiento de datos en tiempo real.
- **Firebase Storage**: Almacenamiento de imágenes y adjuntos.
- **Firebase Analytics**: Seguimiento de eventos y métricas.
- **Provider**: Gestión de estado reactivo.

## 6. Seguridad
- Reglas de Firestore para proteger datos de usuarios y grupos.
- Validación de roles y permisos en la lógica de negocio.
- Exclusión de archivos sensibles en .gitignore.

## 7. Buenas Prácticas
- Código modular y reutilizable.
- Separación clara entre lógica de negocio y presentación.
- Uso de streams y listeners para datos en tiempo real.
- Manejo de errores y estados de carga en la UI.

---
Este blueprint resume la arquitectura y los componentes clave de SplitUp, facilitando su mantenimiento y escalabilidad.
