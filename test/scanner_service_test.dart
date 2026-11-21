import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:macro_scan/models.dart';
import 'package:macro_scan/scanner_service.dart';

Map<String, Object?> validBody({
  double confidence = .82,
  double low = 140,
  double guess = 180,
  double high = 230,
  String name = 'Grilled chicken breast',
  Map<String, double> nutrition = const {
    'calories_kcal': 165,
    'protein_g': 31,
    'carbs_g': 0,
    'fat_g': 3.6,
  },
}) =>
    <String, Object?>{
      'food_detected': true,
      'items': [
        {
          'food_name': name,
          'confidence': confidence,
          'portion_guess_g': guess,
          'portion_low_g': low,
          'portion_high_g': high,
          'nutrition_per_100g': nutrition,
        },
      ],
      'clarification': '',
    };

void main() {
  group('Scanner response parsing', () {
    test('returns a validated primary food and range', () {
      final estimate = parseScanResponse(jsonEncode(validBody()));
      expect(estimate.foodName, 'Grilled chicken breast');
      expect(estimate.confidence, .82);
      expect(estimate.confidencePercent, 82);
      expect(estimate.portionGuessG, 180);
      expect(estimate.portionLowG, 140);
      expect(estimate.portionHighG, 230);
      expect(estimate.aiFood.source, FoodSource.aiEstimate);
      expect(estimate.aiFood.kcal100, 165);
      expect(estimate.aiFood.protein100, 31);
    });

    test('never displays 100 percent confidence', () {
      final estimate =
          parseScanResponse(jsonEncode(validBody(confidence: 1.0)));
      expect(estimate.confidence, .95);
      expect(estimate.confidencePercent, 95);
    });

    test('widens unrealistically tight portion bounds', () {
      final estimate = parseScanResponse(
        jsonEncode(validBody(low: 100, guess: 100, high: 100)),
      );
      expect(estimate.portionLowG, lessThan(estimate.portionGuessG));
      expect(estimate.portionHighG, greaterThan(estimate.portionGuessG));
      expect(estimate.portionLowG, lessThanOrEqualTo(80));
      expect(estimate.portionHighG, greaterThanOrEqualTo(120));
    });

    test('rejects non-food responses with the food-only message', () {
      final body = jsonEncode(<String, Object?>{
        'food_detected': false,
        'items': <Object>[],
        'clarification': 'This is not food.',
      });
      expect(
        () => parseScanResponse(body),
        throwsA(
          isA<ScannerException>().having(
            (error) => error.message,
            'message',
            contains('food'),
          ),
        ),
      );
    });

    test('rejects invalid JSON', () {
      expect(
        () => parseScanResponse('<html>oops</html>'),
        throwsA(isA<ScannerException>()),
      );
    });

    test('rejects a missing portion', () {
      final body = validBody();
      final item = (body['items'] as List).first as Map<String, Object?>;
      item.remove('portion_guess_g');
      expect(
        () => parseScanResponse(jsonEncode(body)),
        throwsA(isA<ScannerException>()),
      );
    });

    test('rejects invalid portion ordering', () {
      expect(
        () => parseScanResponse(
          jsonEncode(validBody(low: 200, guess: 180, high: 230)),
        ),
        throwsA(isA<ScannerException>()),
      );
    });

    test('rejects boolean confidence values', () {
      final body = validBody();
      final item = (body['items'] as List).first as Map<String, Object?>;
      item['confidence'] = true;
      expect(
        () => parseScanResponse(jsonEncode(body)),
        throwsA(isA<ScannerException>()),
      );
    });

    test('rejects implausible nutrition', () {
      expect(
        () => parseScanResponse(
          jsonEncode(validBody(nutrition: const {
            'calories_kcal': 900,
            'protein_g': 80,
            'carbs_g': 80,
            'fat_g': 80,
          })),
        ),
        throwsA(isA<ScannerException>()),
      );
    });

    test('sanitizes control characters in a food name', () {
      final estimate = parseScanResponse(
        jsonEncode(validBody(name: 'Grilled\nChicken\u0000 breast')),
      );
      expect(estimate.foodName, 'Grilled Chicken breast');
    });

    test('bounds an extremely long food name', () {
      final estimate = parseScanResponse(
        jsonEncode(validBody(name: 'Chicken ' * 40)),
      );
      expect(estimate.foodName.length, 120);
    });

    test('ignores extra response fields', () {
      final body = validBody();
      body['debug'] = 'remove me';
      final estimate = parseScanResponse(jsonEncode(body));
      expect(estimate.foodName, 'Grilled chicken breast');
    });
  });

  group('Scanner configuration', () {
    test('supports the same image formats as the backend', () {
      expect(isSupportedImageMime('image/jpeg'), isTrue);
      expect(isSupportedImageMime('image/png'), isTrue);
      expect(isSupportedImageMime('image/gif'), isTrue);
      expect(isSupportedImageMime('image/webp'), isTrue);
      expect(isSupportedImageMime('image/heic'), isFalse);
      expect(isSupportedImageMime('application/pdf'), isFalse);
    });

    test('is not configured without a build URL', () {
      final service = ScannerService(endpoint: '', accessToken: '');
      expect(service.isConfigured, isFalse);
      expect(service.configurationError, contains('available'));
      expect(service.configurationError, isNot(contains('http')));
      service.dispose();
    });

    test('rejects plain HTTP for a remote host', () {
      final service = ScannerService(
        endpoint: 'http://example.com/api/analyze',
        accessToken: '',
      );
      expect(service.isConfigured, isFalse);
      expect(service.configurationError, contains('secure connection'));
      service.dispose();
    });

    test('allows loopback HTTP for local development', () {
      final service = ScannerService(
        endpoint: 'http://localhost:8000/api/analyze',
        accessToken: '',
      );
      expect(service.isConfigured, isTrue);
      service.dispose();
    });

    test('allows private LAN HTTP only in debug builds', () {
      final lan = ScannerService(
        endpoint: 'http://192.168.1.20:8000/api/analyze',
        accessToken: '',
      );
      expect(lan.isConfigured, isTrue);
      lan.dispose();
      final otherPrivate = ScannerService(
        endpoint: 'http://172.20.0.2:8000/api/analyze',
        accessToken: '',
      );
      expect(otherPrivate.isConfigured, isTrue);
      otherPrivate.dispose();
      final publicAddress = ScannerService(
        endpoint: 'http://172.32.0.2:8000/api/analyze',
        accessToken: '',
      );
      expect(publicAddress.isConfigured, isFalse);
      publicAddress.dispose();
    });

    test('accepts HTTPS', () {
      final service = ScannerService(
        endpoint: 'https://scanner.example.test/api/analyze',
        accessToken: '',
      );
      expect(service.isConfigured, isTrue);
      service.dispose();
    });

    test('rejects a malformed endpoint without exposing it', () {
      final service = ScannerService(
        endpoint: 'not a url',
        accessToken: '',
      );
      expect(service.isConfigured, isFalse);
      expect(service.configurationError, contains('available'));
      service.dispose();
    });
  });

  group('Scanner HTTP handling', () {
    test('sends the token header and parses a success response', () async {
      String? token;
      final client = MockClient((request) async {
        token = request.headers['x-scanner-token'];
        expect(request.method, 'POST');
        return http.Response(
          jsonEncode(validBody()),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final service = ScannerService(
        endpoint: 'https://scanner.example.test/api/analyze',
        accessToken: 'test-token',
        client: client,
      );
      final estimate = await service.analyze(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        filename: 'food.jpg',
        mimeType: 'image/jpeg',
      );
      expect(token, 'test-token');
      expect(estimate.foodName, 'Grilled chicken breast');
      service.dispose();
    });

    test('maps a food-only 422 to a clear message', () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(<String, String>{
            'detail':
                'Nouri scans food only. Try a clear photo showing edible food.',
          }),
          422,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      );
      final service = ScannerService(
        endpoint: 'https://scanner.example.test/api/analyze',
        accessToken: '',
        client: client,
      );
      await expectLater(
        service.analyze(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          filename: 'food.jpg',
          mimeType: 'image/jpeg',
        ),
        throwsA(
          isA<ScannerException>().having(
            (error) => error.message,
            'message',
            contains('food only'),
          ),
        ),
      );
      service.dispose();
    });

    test('maps server errors to a friendly fallback', () async {
      final client = MockClient(
        (request) async => http.Response('upstream failed', 503),
      );
      final service = ScannerService(
        endpoint: 'https://scanner.example.test/api/analyze',
        accessToken: '',
        client: client,
      );
      await expectLater(
        service.analyze(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          filename: 'food.jpg',
          mimeType: 'image/jpeg',
        ),
        throwsA(
          isA<ScannerException>().having(
            (error) => error.message,
            'message',
            contains('temporarily unavailable'),
          ),
        ),
      );
      service.dispose();
    });

    test('maps a provider timeout to a clear message', () async {
      final client = MockClient(
        (request) async => http.Response('gateway timeout', 504),
      );
      final service = ScannerService(
        endpoint: 'https://scanner.example.test/api/analyze',
        accessToken: '',
        client: client,
      );
      await expectLater(
        service.analyze(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          filename: 'food.jpg',
          mimeType: 'image/jpeg',
        ),
        throwsA(
          isA<ScannerException>().having(
            (error) => error.message,
            'message',
            contains('took too long'),
          ),
        ),
      );
      service.dispose();
    });

    test('rejects an invalid success body', () async {
      final client = MockClient(
        (request) async => http.Response('{"food_detected": true}', 200),
      );
      final service = ScannerService(
        endpoint: 'https://scanner.example.test/api/analyze',
        accessToken: '',
        client: client,
      );
      await expectLater(
        service.analyze(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          filename: 'food.jpg',
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<ScannerException>()),
      );
      service.dispose();
    });

    test('rejects an empty image before sending', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });
      final service = ScannerService(
        endpoint: 'https://scanner.example.test/api/analyze',
        accessToken: '',
        client: client,
      );
      await expectLater(
        service.analyze(
          bytes: Uint8List(0),
          filename: 'food.jpg',
          mimeType: 'image/jpeg',
        ),
        throwsA(isA<ScannerException>()),
      );
      expect(called, isFalse);
      service.dispose();
    });
  });
}
