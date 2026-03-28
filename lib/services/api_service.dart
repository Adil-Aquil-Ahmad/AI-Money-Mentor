import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  ApiException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// Main API Service for handling all backend communication
class ApiService {
  static final ApiService _instance = ApiService._internal();

  late http.Client _client;
  String? _authToken;

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    _client = http.Client();
  }

  /// Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Clear authentication token
  void clearAuthToken() {
    _authToken = null;
  }

  /// Build request headers with proper content type and auth
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  /// Generic GET request with type casting
  Future<T> get<T>(
    String endpoint, {
    T Function(dynamic json)? fromJson,
    bool requireAuth = false,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      final response = await _client
          .get(
            uri,
            headers: _getHeaders(includeAuth: requireAuth),
          )
          .timeout(
            const Duration(seconds: ApiConfig.receiveTimeout),
            onTimeout: () => throw ApiException(
              message: 'Request timeout',
              statusCode: 408,
            ),
          );

      return _handleResponse<T>(response, fromJson);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Generic POST request with type casting
  Future<T> post<T>(
    String endpoint, {
    required dynamic body,
    T Function(dynamic json)? fromJson,
    bool requireAuth = false,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      final response = await _client
          .post(
            uri,
            headers: _getHeaders(includeAuth: requireAuth),
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: ApiConfig.sendTimeout),
            onTimeout: () => throw ApiException(
              message: 'Request timeout',
              statusCode: 408,
            ),
          );

      return _handleResponse<T>(response, fromJson);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Generic PUT request with type casting
  Future<T> put<T>(
    String endpoint, {
    required dynamic body,
    T Function(dynamic json)? fromJson,
    bool requireAuth = false,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      final response = await _client
          .put(
            uri,
            headers: _getHeaders(includeAuth: requireAuth),
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: ApiConfig.sendTimeout),
            onTimeout: () => throw ApiException(
              message: 'Request timeout',
              statusCode: 408,
            ),
          );

      return _handleResponse<T>(response, fromJson);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Generic DELETE request
  Future<T> delete<T>(
    String endpoint, {
    T Function(dynamic json)? fromJson,
    bool requireAuth = false,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      final response = await _client
          .delete(
            uri,
            headers: _getHeaders(includeAuth: requireAuth),
          )
          .timeout(
            const Duration(seconds: ApiConfig.receiveTimeout),
            onTimeout: () => throw ApiException(
              message: 'Request timeout',
              statusCode: 408,
            ),
          );

      return _handleResponse<T>(response, fromJson);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Network error: $e');
    }
  }

  /// Handle response with proper error handling and type conversion
  T _handleResponse<T>(
    http.Response response,
    T Function(dynamic json)? fromJson,
  ) {
    try {
      final statusCode = response.statusCode;

      if (statusCode == 204) {
        // No content
        return null as T;
      }

      final decodedResponse = jsonDecode(response.body);

      if (statusCode >= 200 && statusCode < 300) {
        // Success
        if (fromJson != null) {
          return fromJson(decodedResponse);
        }
        return decodedResponse as T;
      } else if (statusCode == 401) {
        throw ApiException(
          message: 'Unauthorized',
          statusCode: statusCode,
          responseBody: response.body,
        );
      } else if (statusCode == 404) {
        throw ApiException(
          message: 'Not found',
          statusCode: statusCode,
          responseBody: response.body,
        );
      } else if (statusCode == 500) {
        throw ApiException(
          message: 'Server error',
          statusCode: statusCode,
          responseBody: response.body,
        );
      } else {
        throw ApiException(
          message: 'API error: ${decodedResponse['detail'] ?? 'Unknown error'}',
          statusCode: statusCode,
          responseBody: response.body,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Failed to parse response: $e',
      );
    }
  }

  /// Check backend connectivity
  Future<bool> checkConnection() async {
    try {
      final response = await get(
        ApiConfig.ping,
        fromJson: (json) => json['status'] == 'ok',
      );
      return response;
    } catch (e) {
      return false;
    }
  }
}

/// Singleton instance for easy access
final apiService = ApiService();
