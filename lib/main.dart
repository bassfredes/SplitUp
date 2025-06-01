import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'config/firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'providers/expense_provider.dart'; // Import ExpenseProvider
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
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode; // Añadido kDebugMode
import 'package:flutter/scheduler.dart'; // Añadido para SchedulerBinding
import 'services/cache_service.dart';
import 'services/connectivity_service.dart';
import 'widgets/firestore_usage_widget.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // Importación para FirebaseAppCheck
import 'introduction_animation/initial_screen.dart'; // Importa la nueva pantalla inicial
import 'services/settings_service.dart'; // Importa el servicio de configuración
import 'introduction_animation/introduction_animation_screen.dart'; // Importa la pantalla de animación de introducción

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar el servicio de configuración primero
  await SettingsService.instance.init();

  // Luego inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await initializeAppCheck(); // Inicializa y ACTIVA App Check
  
  await CacheService().init();
  final connectivityService = ConnectivityService();
  await connectivityService.checkConnectivity();

  // Escuchar cambios en el token de App Check
  // Ahora es seguro configurar este listener porque App Check ya está activado
  FirebaseAppCheck.instance.onTokenChange.listen((token) {
    if (kDebugMode) {
      print('App Check token changed: ${token ?? "null"}');
    }
  });

  // Escuchar cambios en el estado de autenticación y token de ID
  firebase_auth.FirebaseAuth.instance.authStateChanges().listen((firebase_auth.User? user) {
    if (kDebugMode) {
      print('Auth state changed: User is ${user == null ? "null" : user.uid}');
    }
  });

  firebase_auth.FirebaseAuth.instance.idTokenChanges().listen((firebase_auth.User? user) {
    if (user == null) {
      if (kDebugMode) {
        print('ID token changed: User is null');
      }
    } else {
      user.getIdToken(true).then((token) {
        if (kDebugMode) {
          print('ID token changed: User ${user.uid}, New ID Token: ${token ?? "null"}');
        }
      }).catchError((e) {
        if (kDebugMode) {
          print('Error getting ID token on change: $e');
        }
      });
    }
  });

  // Configura la persistencia de sesión para web
  if (kIsWeb) {
    // Intenta "calentar" App Check obteniendo un token ANTES de setPersistence
    try {
      final String? token = await FirebaseAppCheck.instance.getToken(true); // true fuerza el refresco
      if (kDebugMode) {
        print('App Check token obtained explicitly in main (before persistence): ${token != null ? "OK (token: $token)" : "Failed or Null"}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error explicitly getting App Check token in main (before persistence): $e');
      }
    }

    try {
      await firebase_auth.FirebaseAuth.instance.setPersistence(firebase_auth.Persistence.LOCAL);
      if (kDebugMode) {
        print("Firebase Auth persistence set to LOCAL successfully for web.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error setting Firebase Auth persistence for web: $e");
      }
    }
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
        ChangeNotifierProvider(create: (_) => ExpenseProvider()), // ExpenseProvider added here
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
        home: const InitialScreen(), // Cambiado a InitialScreen
        navigatorObservers: [SplitUpApp.observer],
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/groups': (context) => const DashboardScreen(),
          '/email_verification': (context) => const EmailVerificationScreen(),
          '/account': (context) => const AccountScreen(),
          '/account/edit_name': (context) => const EditNameScreen(),
          '/account/change_password': (context) => const ChangePasswordScreen(),
          '/account/create_password': (context) => const CreatePasswordScreen(),
          '/account/link_google': (context) => const LinkGoogleScreen(),
          '/welcome': (context) => const IntroductionAnimationScreen(), 
        },
        onGenerateRoute: (settings) {
          // Normalize the route name by removing any trailing slash
          String? routeName = settings.name;
          if (routeName != null && routeName.isNotEmpty && routeName.endsWith('/')) {
            routeName = routeName.substring(0, routeName.length - 1);
          }
          // Crear una nueva instancia de RouteSettings con el nombre normalizado
          final normalizedSettings = RouteSettings(name: routeName, arguments: settings.arguments);

          // Rutas dinámicas para la sección de grupos
          if (normalizedSettings.name != null && normalizedSettings.name!.startsWith('/group/')) {
            return MaterialPageRoute(
              settings: normalizedSettings, // Usar normalizedSettings
              builder: (context) {
                // ExpenseProvider is now global, no need to provide it here.
                // The Builder's logic or direct screen routing happens here.
                final uri = Uri.parse(normalizedSettings.name!); 
                final segments = uri.pathSegments;

                // Ruta para editar un gasto: /group/{groupId}/expense/{expenseId}/edit
                if (segments.length == 5 && segments[0] == 'group' && segments[2] == 'expense' && segments[4] == 'edit') {
                  final groupId = segments[1];
                  final expenseId = segments[3];

                  if (groupId.isNotEmpty && expenseId.isNotEmpty) {
                    return EditExpenseScreen(
                      groupId: groupId,
                      expenseId: expenseId,
                    );
                  }
                }
                
                // Ruta para ver detalle de un gasto: /group/{groupId}/expense/{expenseId}
                if (segments.length == 4 && segments[0] == 'group' && segments[2] == 'expense') {
                  final groupId = segments[1];
                  final expenseId = segments[3];
                  return ExpenseDetailScreen(
                    groupId: groupId,
                    expenseId: expenseId,
                  );
                }
                
                // Ruta para ver detalle de un grupo: /group/{groupId}
                if (segments.length == 2 && segments[0] == 'group') {
                  final groupId = segments[1];
                  return FutureBuilder(
                    future: FirestoreService().getGroup(groupId).first,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(body: Center(child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                        return const Scaffold(body: Center(child: Text('Group not found or error loading group.')));
                      }
                      return GroupDetailScreen(group: snapshot.data!);
                    },
                  );
                }
                
                return const Scaffold(body: Center(child: Text('Unknown route within group section')));
              },
            );
          }
          
          // Rutas estáticas (sin cambios)
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
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (kDebugMode) {
            print("RootRedirector: ConnectionState.waiting - mostrando loader inicial.");
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator(key: Key("root_initial_loader"))));
        }

        final user = snapshot.data;
        
        // Usar addPostFrameCallback para la navegación después de que el frame actual se construya.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            if (kDebugMode) {
              print("RootRedirector: Contexto no montado en addPostFrameCallback. Abortando navegación.");
            }
            return;
          }

          final String? currentRouteName = ModalRoute.of(context)?.settings.name;
          if (kDebugMode) {
            print("RootRedirector: addPostFrameCallback - User: ${user?.uid}, CurrentRoute: $currentRouteName");
          }

          if (user == null) { // No hay usuario autenticado
            // Navega a login si no está ya en /login.
            // Asumimos que /register no es una ruta manejada por RootRedirector directamente o no existe en las rutas base.
            if (currentRouteName != '/login') {
              if (kDebugMode) {
                print("RootRedirector: No hay usuario, redirigiendo a /login desde $currentRouteName");
              }
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            } else {
              if (kDebugMode) {
                print("RootRedirector: No hay usuario, ya en /login.");
              }
            }
          } else { // Hay un usuario autenticado
            if (!user.emailVerified) { // Email no verificado
              if (currentRouteName != '/email_verification') {
                if (kDebugMode) {
                  print("RootRedirector: Usuario con email no verificado, redirigiendo a /email_verification desde $currentRouteName");
                }
                Navigator.pushNamedAndRemoveUntil(context, '/email_verification', (route) => false);
              } else {
                 if (kDebugMode) {
                  print("RootRedirector: Usuario con email no verificado, ya en /email_verification.");
                }
              }
            } else { // Email verificado
              // Si está en la raíz, login, o verificación, redirigir al dashboard.
              if (currentRouteName == '/' || currentRouteName == '/login' || currentRouteName == '/email_verification') {
                if (kDebugMode) {
                  print("RootRedirector: Usuario verificado, redirigiendo a /dashboard desde $currentRouteName");
                }
                Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
              } else {
                if (kDebugMode) {
                  print("RootRedirector: Usuario verificado, ya en una ruta interna ($currentRouteName) o desconocida. No se redirige desde RootRedirector.");
                }
              }
            }
          }
        });

        // Lógica para devolver un widget síncrono mientras la navegación en addPostFrameCallback se procesa.
        final String? currentRouteNameForWidget = ModalRoute.of(context)?.settings.name;
        if (kDebugMode) {
          print("RootRedirector: Build síncrono - User: ${user?.uid}, CurrentRouteForWidget: $currentRouteNameForWidget");
        }

        if (user == null) {
          if (currentRouteNameForWidget == '/login') {
            if (kDebugMode) {
              print("RootRedirector: Build síncrono - Devolviendo LoginScreen (ya en /login).");
            }
            return const LoginScreen();
          }
          if (kDebugMode) {
            print("RootRedirector: Build síncrono - No hay usuario, no en /login. Devolviendo loader (esperando redirección).");
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator(key: Key("root_user_null_loader"))));
        } else {
          if (!user.emailVerified) {
            if (currentRouteNameForWidget == '/email_verification') {
              if (kDebugMode) {
                print("RootRedirector: Build síncrono - Devolviendo EmailVerificationScreen (ya en /email_verification).");
              }
              return const EmailVerificationScreen();
            }
            if (kDebugMode) {
              print("RootRedirector: Build síncrono - Email no verificado, no en /email_verification. Devolviendo loader (esperando redirección).");
            }
            return const Scaffold(body: Center(child: CircularProgressIndicator(key: Key("root_email_not_verified_loader"))));
          } else { // Usuario autenticado y verificado
            if (currentRouteNameForWidget == '/' || currentRouteNameForWidget == '/login' || currentRouteNameForWidget == '/email_verification') {
              if (kDebugMode) {
                print("RootRedirector: Build síncrono - Usuario verificado, en ruta de pre-autenticación. Devolviendo loader (esperando redirección a dashboard).");
              }
              return const Scaffold(body: Center(child: CircularProgressIndicator(key: Key("root_verified_auth_path_loader"))));
            }
            if (kDebugMode) {
              print("RootRedirector: Build síncrono - Usuario verificado, en ruta interna. Devolviendo SizedBox.shrink().");
            }
            return const SizedBox.shrink();
          }
        }
      },
    );
  }
}
