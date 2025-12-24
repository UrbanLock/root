import 'package:app/core/api/api_client.dart';
import 'package:app/core/api/api_exception.dart';
import 'package:app/core/config/api_config.dart';
import 'package:app/features/profile/data/repositories/donation_repository.dart';
import 'package:app/features/profile/domain/models/donation.dart';

class DonationRepositoryImpl implements DonationRepository {
  final ApiClient _apiClient;

  DonationRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<Donation>> getDonations({int page = 1, int limit = 20}) async {
    try {
      final response = await _apiClient.get(
        ApiConfig.donateEndpoint,
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
        requireAuth: true,
      );

      // ApiClient restituisce direttamente `data` del backend:
      // { items: [...], pagination: {...} }
      if (!response.containsKey('items')) {
        throw Exception('Formato risposta donazioni non riconosciuto');
      }

      final items = response['items'] as List<dynamic>;
      return items
          .map((e) => Donation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento delle donazioni: ${e.message}');
    }
  }

  @override
  Future<Donation> getDonationById(String id) async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.donateEndpoint}/$id',
        requireAuth: true,
      );

      final donationJson = response['donation'] as Map<String, dynamic>?;
      if (donationJson == null) {
        throw Exception('Formato risposta dettaglio donazione non riconosciuto');
      }
      return Donation.fromJson(donationJson);
    } on ApiException catch (e) {
      throw Exception('Errore nel caricamento della donazione: ${e.message}');
    }
  }

  @override
  Future<Donation> createDonation({
    required String itemName,
    required String equipmentType,
    String? category,
    required String description,
    String? base64Photo,
  }) async {
    try {
      // Mappa il tipo scelto in UI ai valori richiesti dal backend
      // Backend accetta: sport, libri, giochi, altro
      String tipoBackend;
      switch (equipmentType.toLowerCase()) {
        case 'sport':
        case 'sportivi':
        case 'sportivo':
        case 'sportiva':
        case 'sport':
        case 'sport ':
        case 'sport ':
        case 'sport ':
        case 'sport ':
        case 'sport ':
        case 'sport':
        case 'sport ':
        case 'sportivi ':
        case 'sportivi':
        case 'sport':
        case 'sport ':
        case 'sportivi ':
        case 'sportivi':
        case 'sport':
        case 'sport ':
        case 'sportivi ':
        case 'sportivi':
          tipoBackend = 'sport';
          break;
        case 'libri':
        case 'libro':
          tipoBackend = 'libri';
          break;
        case 'giochi':
        case 'gioco':
        case 'game':
          tipoBackend = 'giochi';
          break;
        default:
          tipoBackend = 'altro';
      }

      final body = <String, dynamic>{
        'nomeOggetto': itemName,
        'tipoAttrezzatura': tipoBackend,
        'descrizione': description,
      };

      if (category != null && category.isNotEmpty) {
        body['categoria'] = category;
      }
      if (base64Photo != null && base64Photo.isNotEmpty) {
        body['photo'] = base64Photo;
      }

      final response = await _apiClient.post(
        ApiConfig.donateEndpoint,
        body: body,
        requireAuth: true,
      );

      final donationJson = response['donation'] as Map<String, dynamic>?;
      if (donationJson == null) {
        throw Exception(
            'Formato risposta creazione donazione non riconosciuto');
      }
      return Donation.fromJson(donationJson);
    } on ApiException catch (e) {
      throw Exception('Errore nella creazione della donazione: ${e.message}');
    }
  }

  @override
  Future<Donation> updateDonation({
    required String id,
    String? itemName,
    String? equipmentType,
    String? category,
    String? description,
    String? base64Photo,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (itemName != null) body['nomeOggetto'] = itemName;
      if (equipmentType != null) {
        String tipoBackend;
        switch (equipmentType.toLowerCase()) {
          case 'sport':
          case 'sportivi':
          case 'sportivo':
          case 'sportiva':
            tipoBackend = 'sport';
            break;
          case 'libri':
          case 'libro':
            tipoBackend = 'libri';
            break;
          case 'giochi':
          case 'gioco':
          case 'game':
            tipoBackend = 'giochi';
            break;
          default:
            tipoBackend = 'altro';
        }
        body['tipoAttrezzatura'] = tipoBackend;
      }
      if (category != null) body['categoria'] = category;
      if (description != null) body['descrizione'] = description;
      if (base64Photo != null && base64Photo.isNotEmpty) {
        body['photo'] = base64Photo;
      }

      final response = await _apiClient.put(
        '${ApiConfig.donateEndpoint}/$id',
        body: body.isEmpty ? null : body,
        requireAuth: true,
      );

      final donationJson = response['donation'] as Map<String, dynamic>?;
      if (donationJson == null) {
        throw Exception(
            'Formato risposta aggiornamento donazione non riconosciuto');
      }
      return Donation.fromJson(donationJson);
    } on ApiException catch (e) {
      throw Exception(
          'Errore nell\'aggiornamento della donazione: ${e.message}');
    }
  }

  @override
  Future<void> deleteDonation(String id) async {
    try {
      await _apiClient.delete(
        '${ApiConfig.donateEndpoint}/$id',
        requireAuth: true,
      );
    } on ApiException catch (e) {
      throw Exception(
          'Errore nella cancellazione della donazione: ${e.message}');
    }
  }

  @override
  Future<Donation> schedulePickup({
    required String id,
    required DateTime pickupDate,
    String? note,
  }) async {
    try {
      final body = <String, dynamic>{
        'dataRitiro': pickupDate.toIso8601String(),
      };
      if (note != null && note.isNotEmpty) {
        body['note'] = note;
      }

      final response = await _apiClient.post(
        '${ApiConfig.donateEndpoint}/$id/schedule-pickup',
        body: body,
        requireAuth: true,
      );

      final donationJson = response['donation'] as Map<String, dynamic>?;
      if (donationJson == null) {
        throw Exception(
            'Formato risposta schedule-pickup donazione non riconosciuto');
      }
      return Donation.fromJson(donationJson);
    } on ApiException catch (e) {
      throw Exception(
          'Errore nella pianificazione del ritiro: ${e.message}');
    }
  }
}


