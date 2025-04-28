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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SplitUpApp());
}

class SplitUpApp extends StatelessWidget {
  const SplitUpApp({super.key});

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
        onGenerateRoute: (settings) {
          // Ruta dinámica para detalle de grupo
          if (settings.name != null && settings.name!.startsWith('/group/')) {
            final uri = Uri.parse(settings.name!);
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
      future: Future.value(firebase_auth.FirebaseAuth.instance.currentUser),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          Future.microtask(() => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false));
          return const SizedBox.shrink();
        }
        final user = snapshot.data!;
        if (!user.emailVerified) {
          Future.microtask(() => Navigator.pushNamedAndRemoveUntil(context, '/email_verification', (route) => false));
          return const SizedBox.shrink();
        }
        Future.microtask(() => Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false));
        return const SizedBox.shrink();
      },
    );
  }
}
