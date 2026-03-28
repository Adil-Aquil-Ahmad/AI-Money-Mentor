import 'package:flutter/material.dart';
import '../screens/layout/main_layout.dart';
import '../screens/chat_advisor/chat_advisor_screen.dart';
import '../screens/financial_profile/financial_profile_screen.dart';
import '../screens/health_score/health_score_screen.dart';
import '../screens/portfolio_tracker/portfolio_tracker_screen.dart';
import '../screens/fire_calculator/fire_calculator_screen.dart';
import '../screens/what_if_simulator/what_if_simulator_screen.dart';
import '../screens/auth/login_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String chatAdvisor = '/chat-advisor';
  static const String profile = '/profile';
  static const String healthScore = '/health-score';
  static const String portfolio = '/portfolio';
  static const String fireCalculator = '/fire-calculator';
  static const String whatIf = '/what-if';
  static const String login = '/login';

  static Map<String, WidgetBuilder> get routes {
    return {
      home: (_) => const MainLayoutWrapper(),
      chatAdvisor: (_) => const ChatAdvisorScreen(),
      profile: (_) => const FinancialProfileScreen(),
      healthScore: (_) => const HealthScoreScreen(),
      portfolio: (_) => const PortfolioTrackerScreen(),
      fireCalculator: (_) => const FireCalculatorScreen(),
      whatIf: (_) => const WhatIfSimulatorScreen(),
      login: (_) => const LoginScreen(),
    };
  }
}
