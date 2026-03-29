import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../layout/main_layout.dart';
import 'login_screen.dart';
import '../../theme/app_colors.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
  }

  @override
  Widget build(BuildContext context) {
    // Read potential routing arguments passed safely during conditional auth flows
    final args = ModalRoute.of(context)?.settings.arguments;
    final initialIndex = args is int ? args : 0;

    return StreamBuilder<User?>(
      stream: _authStream,
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // The user is fully authenticated
          return MainLayoutWrapper(initialIndex: initialIndex);
        }

        // The user is not authenticated, gracefully present the Login screen
        return const LoginScreen();
      },
    );
  }
}
