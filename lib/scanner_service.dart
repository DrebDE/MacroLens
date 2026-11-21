import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'catalog.dart';
import 'models.dart';

/// Compile-time scanner configuration. Secrets stay in a private build config
/// file and are never rendered in the app.
class AppConfig {
  static const scannerUrl =
      String.fromEnvironment('MACROS_API_URL', defaultValue: '');
  static const scannerAccessToken =
      String.fromEnvironment('SCANNER_ACCESS_TOKEN', defaultValue: '');

  static ScannerService createScannerService() => ScannerService(
        endpoint: scannerUrl,
        accessToken: scannerAccessToken,
      );
}

class ScanEstimate {
  const ScanEstimate({
    required this.foodName,
    required this.confidence,
    required this.portionGuessG,
    required this.portionLowG,
    required this.portionHighG,
    required this.aiFood,
  });

  final String foodName;

  /// Food-identification confidence only, capped below 100% for display.
  final double confidence;
  final double portionGuessG;
  final double portionLowG;
  final double portionHighG;
  final Food aiFood;

  int get confidencePercent => (confidence * 100).round();
}

class ScannerException implements Exception {
  const ScannerException(this.message, {this.retryable = true});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

const foodOnlyMessage =
    'Nouri scans edible food and drinks only. Try a clear photo of one food or dish.';
const invalidScanMessage =
    'Nouri returned an estimate the app could not use. Try another photo or add the food manually.';

/// Hosted food-scanner client. It sends only the selected image; profile and
/// meal data never leave the device through this service.
class ScannerService {
  ScannerService({
    required String endpoint,
    required String accessToken,
    http.Client? client,
  })  : _rawEndpoint = endpoint.trim(),
        _accessToken = accessToken.trim(),
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  final String _rawEndpoint;
  final String _accessToken;
  final http.Client _client;
  final bool _ownsClient;

  String? get configurationError {
    if (_rawEndpoint.isEmpty) {
      return 'AI scanning isn’t available right now. You can still add food manually.';
    }
    final uri = Uri.tryParse(_rawEndpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'AI scanning isn’t available right now. You can still add food manually.';
    }
    if (uri.scheme == 'https') return null;
    if (uri.scheme == 'http' && _isLoopback(uri.host)) return null;
    if (uri.scheme == 'http' && kDebugMode && _isPrivateNetworkHost(uri.host)) {
      return null;
    }
    return 'AI scanning needs a secure connection. You can still add food manually.';
  }

  bool get isConfigured => configurationError == null;

  static bool _isLoopback(String host) =>
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '10.0.2.2';

  /// Allows local LAN testing in debug builds only. Release builds still
  /// require HTTPS, matching the Android network security configuration.
  static bool _isPrivateNetworkHost(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
      octets.add(value);
    }
    if (octets[0] == 10) return true;
    if (octets[0] == 192 && octets[1] == 168) return true;
    if (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) return true;
    return false;
  }

  Future<ScanEstimate> analyze({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final configError = configurationError;
    if (configError != null) {
      throw ScannerException(configError, retryable: false);
    }
    if (bytes.isEmpty) {
      throw const ScannerException(
        'That photo could not be read. Choose it again or take a new photo.',
      );
    }
    if (bytes.length > 15 * 1024 * 1024) {
      throw const ScannerException(
        'That photo is larger than 15 MB. Choose a smaller photo or add the food manually.',
        retryable: false,
      );
    }

    final request = http.MultipartRequest('POST', Uri.parse(_rawEndpoint));
    request.headers['Accept'] = 'application/json';
    if (_accessToken.isNotEmpty) {
      request.headers['x-scanner-token'] = _accessToken;
    }
    try {
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ));
    } on FormatException {
      throw const ScannerException(
        'That image format is not supported. Choose a JPEG, PNG, GIF, or WebP photo.',
        retryable: false,
      );
    }

    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 180));
      final text = utf8.decode(response.bodyBytes, allowMalformed: true);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _statusError(response.statusCode, _detailFromBody(text));
      }
      return parseScanResponse(text);
    } on TimeoutException {
      throw const ScannerException(
        'Nouri took too long to analyze this photo. The free scanner may be waking up. Try again in a moment, or add the food manually.',
      );
    } on http.ClientException {
      throw const ScannerException(
        'Cannot reach Nouri’s scanner. Check your internet connection and try again, or add the food manually.',
      );
    } on ScannerException {
      rethrow;
    } catch (_) {
      throw const ScannerException(
        'Nouri could not complete the scan. Check your connection and try again, or add the food manually.',
      );
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }

  static String? _detailFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] is String) {
        return _safeDetail(decoded['detail'] as String);
      }
    } catch (_) {
      // Ignore non-JSON or malformed error bodies.
    }
    return null;
  }

  static String? _safeDetail(String value) {
    final cleaned = value
        .replaceAll(RegExp('[\\x00-\\x1F\\x7F]'), ' ')
        .replaceAll(RegExp('\\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    return cleaned.length > 220 ? cleaned.substring(0, 220) : cleaned;
  }

  static ScannerException _statusError(int status, String? detail) {
    if (status == 401 || status == 403) {
      return const ScannerException(
        'AI scanning isn’t available for this app right now. You can add the food manually.',
        retryable: false,
      );
    }
    if (status == 413) {
      return const ScannerException(
        'That photo is too large for Nouri. Choose a smaller photo or add the food manually.',
        retryable: false,
      );
    }
    if (status == 415) {
      return const ScannerException(
        'That image format is not supported. Choose a JPEG, PNG, GIF, or WebP photo.',
        retryable: false,
      );
    }
    if (status == 422) {
      return ScannerException(detail ?? foodOnlyMessage, retryable: false);
    }
    if (status == 429) {
      return const ScannerException(
        'Nouri is handling a lot of scans right now. Try again in a moment, or add the food manually.',
      );
    }
    if (status == 504) {
      return ScannerException(
        detail ??
            'Nouri took too long to analyze this photo. Try again in a moment, or add the food manually.',
      );
    }
    if (status >= 500) {
      return ScannerException(
        detail ??
            'Nouri’s scanner is temporarily unavailable. Try again in a moment, or add the food manually.',
      );
    }
    return ScannerException(
      detail ??
          'Nouri could not analyze that photo. Try again or add the food manually.',
    );
  }
}

/// Parses and validates the structured scanner response before the UI can use
/// it. A malformed or physically implausible result is rejected, not guessed.
ScanEstimate parseScanResponse(String body) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    throw const ScannerException(invalidScanMessage);
  }
  if (decoded is! Map) {
    throw const ScannerException(invalidScanMessage);
  }
  if (decoded['food_detected'] != true) {
    throw const ScannerException(foodOnlyMessage, retryable: false);
  }
  final items = decoded['items'];
  if (items is! List || items.isEmpty) {
    throw const ScannerException(invalidScanMessage);
  }
  final item = items.first;
  if (item is! Map) {
    throw const ScannerException(invalidScanMessage);
  }

  final foodName = _cleanName(item['food_name']);
  final confidence = _number(item['confidence']);
  final rawGuess = _number(item['portion_guess_g']);
  final rawLow = _number(item['portion_low_g']);
  final rawHigh = _number(item['portion_high_g']);
  if (confidence == null ||
      confidence < 0 ||
      confidence > 1 ||
      rawGuess == null ||
      rawLow == null ||
      rawHigh == null ||
      rawLow < 1 ||
      rawGuess < 1 ||
      rawHigh > 5000 ||
      rawLow > rawGuess ||
      rawGuess > rawHigh) {
    throw const ScannerException(
      'Nouri returned a portion estimate the app could not use. Try another photo or add the food manually.',
    );
  }

  final guess = math.min(5000, math.max(1, rawGuess.round())).toDouble();
  // A photo is not a scale. Keep a visible low/high range even if an older
  // backend or a model returns an unrealistically tight bound.
  var low = math.min(rawLow, math.max(1, guess * .8)).floorToDouble();
  var high = math.max(rawHigh, math.min(5000, guess * 1.2)).ceilToDouble();
  low = math.min(5000, math.max(1, low)).toDouble();
  high = math.min(5000, math.max(1, high)).toDouble();
  if (low >= guess) low = math.max(1, guess - 1);
  if (high <= guess) high = math.min(5000, guess + 1);
  if (!(low <= guess && guess <= high)) {
    throw const ScannerException(invalidScanMessage);
  }

  final nutrition = item['nutrition_per_100g'];
  if (nutrition is! Map) {
    throw const ScannerException(invalidScanMessage);
  }
  final kcal = _number(nutrition['calories_kcal']);
  final protein = _number(nutrition['protein_g']);
  final carbs = _number(nutrition['carbs_g']);
  final fat = _number(nutrition['fat_g']);
  if (kcal == null ||
      protein == null ||
      carbs == null ||
      fat == null ||
      !Food.plausiblePer100(
        kcal: kcal,
        protein: protein,
        carbs: carbs,
        fat: fat,
      )) {
    throw const ScannerException(
      'Nouri returned nutrition values that do not look right. Try another photo or add the food manually.',
    );
  }

  final aiFood = Food(
    foodName,
    kcal,
    protein,
    carbs,
    fat,
    <String>[foodName],
    source: FoodSource.aiEstimate,
  );
  return ScanEstimate(
    foodName: foodName,
    confidence: math.min(.95, confidence),
    portionGuessG: guess,
    portionLowG: low,
    portionHighG: high,
    aiFood: aiFood,
  );
}

double? _number(Object? value) {
  if (value is! num) return null;
  final result = value.toDouble();
  return result.isFinite ? result : null;
}

String _cleanName(Object? value) {
  if (value is! String) {
    throw const ScannerException(
      'Nouri did not return a usable food name. Try another photo or add the food manually.',
    );
  }
  final cleaned = value
      .replaceAll(RegExp('[\\x00-\\x1F\\x7F]'), ' ')
      .replaceAll(RegExp('\\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) {
    throw const ScannerException(
      'Nouri did not return a usable food name. Try another photo or add the food manually.',
    );
  }
  return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
}

/// Suggests a catalog source for a scan so users can compare catalog values
/// with Nouri’s generic estimate.
Food preferredScanFood(ScanEstimate estimate) =>
    matchFood(estimate.foodName) ?? estimate.aiFood;

bool isSupportedImageMime(String? mimeType) => const <String>{
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
    }.contains(mimeType);
