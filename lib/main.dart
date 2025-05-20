import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'config/firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/email_verification_screen.dart';
import 'services/firestore_service.dart';
import 'screens/expense_detail_screen.dart';
import 'screens/edit_expense_screen.dart';
import 'screens/account_screen.dart';
import 'screens/edit_name_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/create_password_screen.dart';
import 'screens/link_google_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'config/app_check_init.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/cache_service.dart';
import 'services/connectivity_service.dart';
import 'widgets/firestore_usage_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar servicios locales primero
  await CacheService().init();
  final connectivityService = ConnectivityService();
  await connectivityService.checkConnectivity();
  
  // Luego inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeAppCheck(); // Inicializa App Check
  // Configura la persistencia de sesión para web
  if (kIsWeb) {
    await firebase_auth.FirebaseAuth.instance.setPersistence(firebase_auth.Persistence.LOCAL);
  }
  runApp(const SplitUpApp());
}

class SplitUpApp extends StatelessWidget {
  const SplitUpApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        // Agrega aquí otros providers si es necesario
      ],
      child: MaterialApp(
        // Envuelve el contenido con FirestoreUsageWidget tras proveer Directionality
        builder: (context, child) => FirestoreUsageWidget(child: child!),
          title: 'SplitUp  - Splitting up costs and managing expenses',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.teal,
            fontFamily: 'Roboto',
          ),
        initialRoute: '/',
        routes: {
          '/': (context) => const RootRedirector(),
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/groups': (context) => const DashboardScreen(),
          '/email_verification': (context) => const EmailVerificationScreen(),
          '/account': (context) => const AccountScreen(),
          '/account/edit_name': (context) => const EditNameScreen(),
          '/account/change_password': (context) => const ChangePasswordScreen(),
          '/account/create_password': (context) => const CreatePasswordScreen(),
          '/account/link_google': (context) => const LinkGoogleScreen(),
        },
        navigatorObservers: [observer],
        onGenerateRoute: (settings) {
          // Rutas dinámicas para detalle de grupo
          if (settings.name != null && settings.name!.startsWith('/group/')) {
            final uri = Uri.parse(settings.name!);
            final segments = uri.pathSegments;
            
            // Ruta para editar un gasto
            if (segments.length >= 5 && segments[2] == 'expense' && segments[4] == 'edit') {
              final groupId = segments[1];
              final expenseId = segments[3];
              return MaterialPageRoute(
                builder: (context) => EditExpenseScreen(
                  groupId: groupId,
                  expenseId: expenseId,
                ),
                settings: settings,
              );
            }
            
            // Ruta para ver detalle de un gasto
            if (segments.length >= 4 && segments[2] == 'expense') {
              final groupId = segments[1];
              final expenseId = segments[3];
              return MaterialPageRoute(
                builder: (context) => ExpenseDetailScreen(
                  groupId: groupId,
                  expenseId: expenseId,
                ),
                settings: settings,
              );
            }
            
            // Ruta para ver detalle de un grupo
            if (segments.length == 2) {
              final groupId = segments[1];
              return MaterialPageRoute(
                builder: (context) => FutureBuilder(
                  future: FirestoreService().getGroup(groupId).first,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const Scaffold(body: Center(child: Text('Grupo no encontrado')));
                    }
                    return GroupDetailScreen(group: snapshot.data!);
                  },
                ),
                settings: settings,
              );
            }
          }
          
          // Rutas estáticas
          switch (settings.name) {
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/dashboard':
              return MaterialPageRoute(builder: (_) => const DashboardScreen());
            default:
              return null;
          }
        },
      ), // cierra MaterialApp
    ); // cierra MultiProvider
  }
}

class RootRedirector extends StatelessWidget {
  const RootRedirector({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<firebase_auth.User?>(
      future: Future.value(firebase_auth.FirebaseAuth.instance.currentUser), // Usa Future.value para valor inmediato
      builder: (context, snapshot) {
        // Es mejor manejar el estado de carga explícitamente
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator())); // Muestra indicador de carga
        }

        final user = snapshot.data;
        final currentRoute = ModalRoute.of(context)?.settings.name;

        // Usa WidgetsBinding.instance.addPostFrameCallback para navegación después de construir el widget
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!snapshot.hasData || user == null) {
            // Si no hay datos de usuario o el usuario es nulo, navega a login
            if (currentRoute != '/login') {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            }
          } else if (!user.emailVerified) {
            // Si el usuario existe pero el email no está verificado, navega a verificación
            if (currentRoute != '/email_verification') {
              Navigator.pushNamedAndRemoveUntil(context, '/email_verification', (route) => false);
            }
          } else {
            // Si el usuario existe y el email está verificado, navega al dashboard
            if (currentRoute != '/dashboard') {
              Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
            }
          }
        });

        // Devuelve un contenedor vacío mientras la navegación está pendiente
        return const SizedBox.shrink();
      },
    );
  }
}
