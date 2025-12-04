/// Configurazione per le API del backend
/// 
/// **IMPORTANTE**: Quando il backend sarà pronto, aggiornare questi valori:
/// - baseUrl: URL del backend (es. 'https://api.null.app')
/// - apiVersion: Versione dell'API (es. 'v1')
/// - timeout: Timeout per le richieste HTTP
class ApiConfig {
  // TODO: Configurare quando il backend sarà pronto
  static const String baseUrl = 'https://api.null.app'; // URL del backend
  static const String apiVersion = 'v1';
  static const Duration timeout = Duration(seconds: 30);
  
  /// Costruisce l'URL completo per un endpoint
  static String buildUrl(String endpoint) {
    // Rimuove lo slash iniziale se presente
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$baseUrl/api/$apiVersion/$cleanEndpoint';
  }
  
  /// Endpoint per le celle attive
  static const String activeCellsEndpoint = '/cells/active';
  
  /// Endpoint per aprire una cella
  static const String openCellEndpoint = '/cells/open';
  
  /// Endpoint per chiudere una cella (quando lo sportello viene chiuso)
  static const String closeCellEndpoint = '/cells/close';
  
  /// Endpoint per ottenere lo storico utilizzi
  static const String historyEndpoint = '/cells/history';
  
  /// Endpoint per donare un oggetto
  static const String donateEndpoint = '/donations';
  
  /// Endpoint per autenticazione
  static const String loginEndpoint = '/auth/login';
  
  /// Endpoint per ottenere informazioni utente
  static const String userInfoEndpoint = '/user/info';
}


