import 'package:flutter/cupertino.dart';

/// Tipo di cella disponibile in un locker
enum CellType {
  /// Cella con oggetti disponibili per il prestito
  /// L'utente può prendere in prestito oggetti dalla comunità
  borrow('Prendi in prestito', CupertinoIcons.arrow_down_circle_fill, 'Oggetti disponibili per il prestito dalla comunità'),
  
  /// Cella vuota per depositare oggetti personali
  /// L'utente paga per depositare i propri oggetti per un periodo di tempo
  deposit('Deposita oggetto', CupertinoIcons.arrow_up_circle_fill, 'Deposita i tuoi oggetti personali (a pagamento)'),
  
  /// Cella per ritirare prodotti da negozi locali
  /// L'utente ha già comprato il prodotto, il locker viene usato solo per la consegna
  pickup('Ritira prodotto', CupertinoIcons.cart_fill, 'Ritira prodotti già acquistati da negozi locali');

  final String label;
  final IconData icon;
  final String description;

  const CellType(this.label, this.icon, this.description);
}

/// Dimensione della cella
enum CellSize {
  small('Piccola', 'Fino a 20x20x30 cm'),
  medium('Media', 'Fino a 40x40x50 cm'),
  large('Grande', 'Fino a 60x60x80 cm'),
  extraLarge('Extra Large', 'Oltre 60x60x80 cm');

  final String label;
  final String dimensions;

  const CellSize(this.label, this.dimensions);
}

