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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeAppCheck(); // Inicializa App Check
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
        title: 'SplitUp',
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
          // Ruta dinámica para detalle de grupo
          if (settings.name != null && settings.name!.startsWith('/group/')) {
            final uri = Uri.parse(settings.name!); // Keep '!' here if settings.name is guaranteed non-null by the if condition
            final segments = uri.pathSegments;
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
      ),
    );
  }
}

class RootRedirector extends StatelessWidget {
  const RootRedirector({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<firebase_auth.User?>(
      future: Future.value(firebase_auth.FirebaseAuth.instance.currentUser), // Use Future.value for immediate value
      builder: (context, snapshot) {
        // It's better to handle the loading state explicitly
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator())); // Show loading indicator
        }

        final user = snapshot.data; // No need for ! here, check for null below

        // Use WidgetsBinding.instance.addPostFrameCallback for navigation after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!snapshot.hasData || user == null) {
            // If no user data or user is null, navigate to login
            if (ModalRoute.of(context)?.settings.name != '/login') {
               Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            }
          } else if (!user.emailVerified) {
            // If user exists but email is not verified, navigate to verification
             if (ModalRoute.of(context)?.settings.name != '/email_verification') {
               Navigator.pushNamedAndRemoveUntil(context, '/email_verification', (route) => false);
             }
          } else {
            // If user exists and email is verified, navigate to dashboard
            if (ModalRoute.of(context)?.settings.name != '/dashboard') {
               Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
            }
          }
        });

        // Return an empty container while navigation is pending
        return const SizedBox.shrink();
      },
    );
  }
}
