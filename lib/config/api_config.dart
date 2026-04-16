/// API Configuration for backend connectivity
class ApiConfig {
  /// Backend URL - Update this based on your deployment
  /// For development: http://localhost:8000
  /// For emulator (Android): http://10.0.2.2:8000
  /// For physical device: http://<your-ip>:8000
  static const String baseUrl = 'http://10.12.34.9:8000/api';
  static const String wsUrl = 'ws://10.12.34.9:8000/api/dev';
  
  // For running on Android emulator, use this instead:
  // static const String baseUrl = 'http://10.0.2.2:8000/api';
  
  // For physical device, replace with your machine's IP and use:
  // static const String baseUrl = 'http://10.12.113.193:8000/api';

  // API Endpoints
  static const String ping = '/ping';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String chat = '/chat/message';
  static const String profile = '/profile';
  static const String portfolio = '/investments/portfolio';
  static const String healthScore = '/health-score';
  static const String fireCalculator = '/fire';
  static const String whatIf = '/whatif';
  static const String memory = '/memory';

  // API Timeouts (in seconds)
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
  static const int sendTimeout = 30;
}
