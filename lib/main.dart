import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'config/routes.dart';

void main() {
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
          title: 'Money Mentor',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          initialRoute: '/login',
          routes: AppRoutes.routes,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
