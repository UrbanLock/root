/// Cliente API base per comunicare con il backend
/// 
/// **TODO quando il backend sarà pronto:**
/// 1. Aggiungere gestione token JWT
/// 2. Implementare refresh token automatico
/// 3. Aggiungere retry logic per richieste fallite
/// 4. Implementare logging delle richieste
/// 5. Aggiungere gestione errori centralizzata
/// 
/// Esempio di implementazione:
/// ```dart
/// class ApiClient {
///   final String baseUrl;
///   final http.Client _client;
///   String? _authToken;
/// 
///   ApiClient({required this.baseUrl}) : _client = http.Client();
/// 
///   Future<Map<String, dynamic>> get(String endpoint) async {
///     final response = await _client.get(
///       Uri.parse('$baseUrl$endpoint'),
///       headers: _buildHeaders(),
///     );
///     return _handleResponse(response);
///   }
/// 
///   Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
///     final response = await _client.post(
///       Uri.parse('$baseUrl$endpoint'),
///       headers: _buildHeaders(),
///       body: jsonEncode(body),
///     );
///     return _handleResponse(response);
///   }
/// 
///   Map<String, String> _buildHeaders() {
///     final headers = {'Content-Type': 'application/json'};
///     if (_authToken != null) {
///       headers['Authorization'] = 'Bearer $_authToken';
///     }
///     return headers;
///   }
/// 
///   Map<String, dynamic> _handleResponse(http.Response response) {
///     if (response.statusCode >= 200 && response.statusCode < 300) {
///       return jsonDecode(response.body);
///     } else {
///       throw ApiException(response.statusCode, response.body);
///     }
///   }
/// }
/// ```
class ApiClient {
  // TODO: Implementare quando il backend sarà pronto
  // Per ora questa classe è solo un placeholder per la struttura futura
  
  final String baseUrl;
  
  ApiClient({required this.baseUrl});
  
  // Metodi placeholder - da implementare con chiamate HTTP reali
  // Future<Map<String, dynamic>> get(String endpoint) { ... }
  // Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) { ... }
  // Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) { ... }
  // Future<void> delete(String endpoint) { ... }
}

/// Eccezione personalizzata per errori API
class ApiException implements Exception {
  final int statusCode;
  final String message;
  
  ApiException(this.statusCode, this.message);
  
  @override
  String toString() => 'ApiException: $statusCode - $message';
}


