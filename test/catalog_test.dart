import 'package:flutter_test/flutter_test.dart';
import 'package:macro_scan/catalog.dart';
import 'package:macro_scan/models.dart';

void main() {
  group('Food matching', () {
    test('matches exact aliases', () {
      expect(matchFood('banana')?.name, 'Banana');
      expect(matchFood('White Rice')?.name, 'Cooked white rice');
      expect(matchFood('greek yogurt')?.name, 'Greek yogurt, plain');
    });

    test('matches multi-word labels with whole-word overlap', () {
      expect(
          matchFood('grilled chicken breast')?.name, 'Grilled chicken breast');
      expect(matchFood('steamed white rice')?.name, 'Cooked white rice');
      expect(matchFood('chicken breast')?.name, 'Grilled chicken breast');
    });

    test('handles simple plurals', () {
      expect(matchFood('eggs')?.name, 'Cooked egg');
      expect(matchFood('apples')?.name, 'Apple');
      expect(matchFood('tomatoes')?.name, 'Tomato');
    });

    test('does not match substrings inside unrelated words', () {
      expect(matchFood('cheeseburger'), isNull);
      expect(matchFood('pineapple'), isNull);
    });

    test('returns null for empty or unknown text', () {
      expect(matchFood(''), isNull);
      expect(matchFood('   '), isNull);
      expect(matchFood('pizza margherita'), isNull);
    });
  });

  group('Catalog', () {
    test('all catalog entries use plausible per-100g values', () {
      for (final food in catalog) {
        expect(food.name.trim(), isNotEmpty);
        expect(
          Food.plausiblePer100(
            kcal: food.kcal100,
            protein: food.protein100,
            carbs: food.carbs100,
            fat: food.fat100,
          ),
          isTrue,
          reason: food.name,
        );
        expect(food.source, FoodSource.catalog);
      }
    });

    test('search returns the full catalog for an empty query', () {
      expect(searchCatalog('').length, catalog.length);
    });

    test('search filters by name and alias', () {
      final chicken =
          searchCatalog('chicken').map((food) => food.name).toList();
      expect(chicken, contains('Grilled chicken breast'));
      expect(chicken, contains('Fried chicken'));
      expect(searchCatalog('yogurt').single.name, 'Greek yogurt, plain');
    });

    test('normalization strips punctuation and casing', () {
      expect(normalizeFoodText('  Grilled, CHICKEN!! '), 'grilled chicken');
    });
  });
}
