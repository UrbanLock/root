/// Modello per rappresentare un utente
class User {
  final String utenteId;
  final String nome;
  final String cognome;
  final String ruolo;
  final String? codiceFiscale;
  final String? email;
  final String? telefono;
  final String? tipoAutenticazione; // 'spid' o 'cie'

  const User({
    required this.utenteId,
    required this.nome,
    required this.cognome,
    required this.ruolo,
    this.codiceFiscale,
    this.email,
    this.telefono,
    this.tipoAutenticazione,
  });

  String get nomeCompleto => '$nome $cognome';

  /// Crea un'istanza da JSON (risposta backend)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      utenteId: json['utenteId'] as String,
      nome: json['nome'] as String,
      cognome: json['cognome'] as String,
      ruolo: json['ruolo'] as String? ?? 'utente',
      codiceFiscale: json['codiceFiscale'] as String?,
      email: json['email'] as String?,
      telefono: json['telefono'] as String?,
      tipoAutenticazione: json['tipoAutenticazione'] as String?,
    );
  }

  /// Converte l'istanza in JSON
  Map<String, dynamic> toJson() {
    return {
      'utenteId': utenteId,
      'nome': nome,
      'cognome': cognome,
      'ruolo': ruolo,
      if (codiceFiscale != null) 'codiceFiscale': codiceFiscale,
      if (email != null) 'email': email,
      if (telefono != null) 'telefono': telefono,
      if (tipoAutenticazione != null) 'tipoAutenticazione': tipoAutenticazione,
    };
  }
}

/// Risposta di login con token
class LoginResponse {
  final User user;
  final String accessToken;
  final String refreshToken;
  final int expiresIn; // in secondi

  const LoginResponse({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] as Map<String, dynamic>;
    final tokensData = json['tokens'] as Map<String, dynamic>;

    return LoginResponse(
      user: User.fromJson(userData),
      accessToken: tokensData['accessToken'] as String,
      refreshToken: tokensData['refreshToken'] as String,
      expiresIn: tokensData['expiresIn'] as int,
    );
  }
}





