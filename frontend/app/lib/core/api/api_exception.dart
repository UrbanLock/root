import 'dart:convert';

/// Eccezione personalizzata per errori API
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? errorCode;
  final Map<String, dynamic>? errorData;

  ApiException(
    this.statusCode,
    this.message, {
    this.errorCode,
    this.errorData,
  });

  /// Crea ApiException da risposta HTTP
  factory ApiException.fromResponse(int statusCode, String responseBody) {
    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      
      // Il backend può restituire due formati:
      // 1. { success: false, data: { verified: false, reason: ..., message: ... } } (dal controller)
      // 2. { success: false, error: { message: ..., code: ..., statusCode: ... } } (dall'error handler globale)
      
      Map<String, dynamic>? errorData;
      String message = 'Errore sconosciuto';
      String? errorCode;
      
      // Prova formato 1: data
      if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
        errorData = json['data'] as Map<String, dynamic>;
        if (errorData!['message'] != null) {
          message = errorData!['message'] as String;
        }
      }
      // Prova formato 2: error
      else if (json.containsKey('error') && json['error'] is Map<String, dynamic>) {
        final error = json['error'] as Map<String, dynamic>;
        if (error['message'] != null) {
          message = error['message'] as String;
        }
        if (error['code'] != null) {
          errorCode = error['code'] as String;
        }
        // Crea errorData compatibile con il formato atteso
        errorData = {
          'verified': false,
          'reason': error['code'] as String? ?? 'api_error',
          'message': message,
        };
      }
      // Fallback: cerca message direttamente
      else if (json['message'] != null) {
        message = json['message'] as String;
      }
      
      return ApiException(
        statusCode,
        message,
        errorCode: errorCode,
        errorData: errorData,
      );
    } catch (e) {
      return ApiException(statusCode, responseBody);
    }
  }

  bool isUnauthorized() => statusCode == 401;
  bool isForbidden() => statusCode == 403;
  bool isNotFound() => statusCode == 404;
  bool isBadRequest() => statusCode == 400;
  bool isServerError() => statusCode >= 500 && statusCode < 600;
  bool isClientError() => statusCode >= 400 && statusCode < 500;

  @override
  String toString() => 'ApiException: $statusCode - $message${errorCode != null ? ' (code: $errorCode)' : ''}';
}

/// Eccezione per errori di connessione
class ConnectionException implements Exception {
  final String message;
  final Exception? originalException;

  ConnectionException(this.message, {this.originalException});

  @override
  String toString() => 'ConnectionException: $message';
}

/// Eccezione per errori di validazione
class ValidationException implements Exception {
  final String message;
  final Map<String, List<String>>? fieldErrors;

  ValidationException(this.message, {this.fieldErrors});

  @override
  String toString() => 'ValidationException: $message';
}

/// Eccezione per quando un locker non ha UUID Bluetooth configurato
/// Questa eccezione viene lanciata quando il backend indica che il locker
/// non ha un UUID Bluetooth configurato, permettendo al frontend di
/// attivare la modalità testing (simulazione con timer)
class BluetoothNotConfiguredException implements Exception {
  final String lockerId;
  final String message;

  BluetoothNotConfiguredException(this.lockerId, {String? message})
      : message = message ?? 'Locker $lockerId non ha UUID Bluetooth configurato';

  @override
  String toString() => 'BluetoothNotConfiguredException: $message';
}




