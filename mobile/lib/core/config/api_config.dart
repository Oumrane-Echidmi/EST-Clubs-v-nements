import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Single source of truth for the backend URL. Override with
/// `--dart-define=API_BASE_URL=https://...`.
class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }
}
