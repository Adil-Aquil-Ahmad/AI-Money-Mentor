import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'config/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCxAPmHuMJaF3JcAGu5jrQ5g0CCxyE6Fow",
        appId: "1:799138795500:ios:5726fcd8bbb76480f4bac9", // mapped implicitly for dev
        messagingSenderId: "799138795500",
        projectId: "ai-study-mentor-8e9d1",
        authDomain: "ai-study-mentor-8e9d1.firebaseapp.com",
        storageBucket: "ai-study-mentor-8e9d1.firebasestorage.app",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  runApp(const MoneyMentorApp());
}

class MoneyMentorApp extends StatelessWidget {
  const MoneyMentorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Chrysos',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          // Removed manual initialRoute forcing to '/login' so root '/' handles auth correctly
          routes: AppRoutes.routes,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
