import 'package:flutter/material.dart';

/// File temporaneo con i simboli associati ad ogni possibile elemento presente in una cella
/// 
/// **TODO quando il backend sarà pronto:**
/// - Rimuovere questo file
/// - Le icone verranno fornite dal backend insieme ai dati delle celle
/// - Usare il campo `itemIcon` o simile dal modello LockerCell
/// 
/// Usa Material Icons per una vasta gamma di icone rappresentative

/// Mappa che associa il nome dell'oggetto al suo simbolo/icona
final Map<String, IconData> cellItemIcons = {
  // ============================================
  // OGGETTI SPORTIVI
  // ============================================
  'Palla da calcio': Icons.sports_soccer,
  'Racchetta da tennis': Icons.sports_tennis,
  'Pallone da basket': Icons.sports_basketball,
  'Corda per saltare': Icons.fitness_center,
  'Yoga mat': Icons.self_improvement,
  'Pesi manubri': Icons.fitness_center,
  
  // ============================================
  // OGGETTI PET-FRIENDLY
  // ============================================
  'Ciotola per acqua': Icons.water_drop,
  'Gioco per cani': Icons.toys,
  'Sacchetti igienici': Icons.shopping_bag,
  'Guinzaglio extra': Icons.pets,
  'Asciugamano per animali': Icons.dry_cleaning,
  
  // ============================================
  // OGGETTI CICLOTURISTICI
  // ============================================
  'Kit riparazione': Icons.build,
  'Pompa portatile': Icons.air,
  'Lucchetto bici': Icons.lock,
  'Casco': Icons.safety_check,
  'Borraccia': Icons.local_drink,
  
  // ============================================
  // OGGETTI GENERICI / DEFAULT
  // ============================================
  'Oggetto generico': Icons.inventory_2,
  'Oggetto sconosciuto': Icons.help_outline,
};

/// Ottiene l'icona associata a un nome di oggetto
/// 
/// Se l'oggetto non è nella mappa, restituisce l'icona di default
IconData getIconForItem(String? itemName) {
  if (itemName == null || itemName.isEmpty) {
    return Icons.inventory_2;
  }
  
  // Cerca corrispondenza esatta
  if (cellItemIcons.containsKey(itemName)) {
    return cellItemIcons[itemName]!;
  }
  
  // Se non trova corrispondenza esatta, prova a cercare per parola chiave
  final lowerName = itemName.toLowerCase();
  
  // Sportivi
  if (lowerName.contains('palla') || lowerName.contains('calcio')) {
    return Icons.sports_soccer;
  }
  if (lowerName.contains('pallone') || lowerName.contains('basket')) {
    return Icons.sports_basketball;
  }
  if (lowerName.contains('racchetta') || lowerName.contains('tennis')) {
    return Icons.sports_tennis;
  }
  if (lowerName.contains('corda') || lowerName.contains('saltare')) {
    return Icons.fitness_center;
  }
  if (lowerName.contains('yoga') || lowerName.contains('tappetino') || lowerName.contains('mat')) {
    return Icons.self_improvement;
  }
  if (lowerName.contains('pesi') || lowerName.contains('manubri') || lowerName.contains('peso')) {
    return Icons.fitness_center;
  }
  
  // Pet-friendly
  if (lowerName.contains('ciotola') || lowerName.contains('acqua') || lowerName.contains('cibo')) {
    return Icons.water_drop;
  }
  if (lowerName.contains('gioco') || lowerName.contains('pallina') || lowerName.contains('frisbee') || lowerName.contains('cane')) {
    return Icons.toys;
  }
  if (lowerName.contains('sacchetti') || lowerName.contains('igienici') || lowerName.contains('sacco')) {
    return Icons.shopping_bag;
  }
  if (lowerName.contains('guinzaglio')) {
    return Icons.pets;
  }
  if (lowerName.contains('asciugamano') || lowerName.contains('telo')) {
    return Icons.dry_cleaning;
  }
  
  // Cicloturistici
  if (lowerName.contains('kit') || lowerName.contains('riparazione') || lowerName.contains('attrezzi')) {
    return Icons.build;
  }
  if (lowerName.contains('pompa') || lowerName.contains('gonfiare')) {
    return Icons.air;
  }
  if (lowerName.contains('lucchetto') || lowerName.contains('catena') || lowerName.contains('serratura')) {
    return Icons.lock;
  }
  if (lowerName.contains('casco') || lowerName.contains('protezione')) {
    return Icons.safety_check;
  }
  if (lowerName.contains('borraccia') || lowerName.contains('bottiglia')) {
    return Icons.local_drink;
  }
  
  // Default
  return Icons.inventory_2;
}

