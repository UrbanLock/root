import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'https://serverurbanlock.onrender.com/api/v1';
  
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    
    return headers;
  }

  static Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    final headers = await _getHeaders();
    var uri = Uri.parse('$baseUrl$endpoint');
    
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    
    final response = await http.get(uri, headers: headers);
    
    // Se il token è scaduto, prova a fare refresh
    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Riprova la richiesta con il nuovo token
        final newHeaders = await _getHeaders();
        return await http.get(uri, headers: newHeaders);
      }
    }
    
    return response;
  }

  static Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final response = await http.post(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    
    // Se il token è scaduto, prova a fare refresh
    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        // Riprova la richiesta con il nuovo token
        final newHeaders = await _getHeaders();
        return await http.post(
          uri,
          headers: newHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    
    return response;
  }

  static Future<http.Response> put(String endpoint, {Map<String, dynamic>? body}) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final response = await http.put(
      uri,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
    
    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        final newHeaders = await _getHeaders();
        return await http.put(
          uri,
          headers: newHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }
    
    return response;
  }

  static Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final response = await http.delete(uri, headers: headers);
    
    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        final newHeaders = await _getHeaders();
        return await http.delete(uri, headers: newHeaders);
      }
    }
    
    return response;
  }

  static Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      
      if (refreshToken == null) {
        return false;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final newAccessToken = data['data']['accessToken'] as String;
          await prefs.setString('access_token', newAccessToken);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}

