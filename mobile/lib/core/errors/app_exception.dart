import 'package:dio/dio.dart';

class AppException implements Exception {
  AppException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;

  static const _messages = {
    'EVENT_FULL': 'Plus de places disponibles.',
    'ALREADY_REGISTERED': 'Vous êtes déjà inscrit.',
    'REGISTRATION_CLOSED': 'Les inscriptions sont closes.',
    'CANCELLATION_NOT_ALLOWED': "L'annulation n'est plus possible.",
    'FORBIDDEN': "Vous n'avez pas accès à cette ressource.",
    'NOT_FOUND': 'Ressource introuvable.',
    'VALIDATION_ERROR': 'Données invalides.',
    'NETWORK_ERROR': 'Connexion impossible. Vérifiez votre réseau.',
    'UNKNOWN': 'Une erreur est survenue.',
  };

  /// Maps a Dio error using the backend `{error:{code,message}}` envelope.
  factory AppException.fromDio(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['error'] is Map) {
      final code = '${body['error']['code']}';
      return AppException(code,
          _messages[code] ?? '${body['error']['message'] ?? _messages['UNKNOWN']}');
    }
    if (e.response == null) {
      return AppException('NETWORK_ERROR', _messages['NETWORK_ERROR']!);
    }
    return AppException('UNKNOWN', _messages['UNKNOWN']!);
  }
}
