import 'package:flutter_test/flutter_test.dart';
import 'package:macro_scan/models.dart';

void main() {
  group('MealEntry nutrition scaling', () {
    const food = Food('Test food', 200, 10, 20, 5, ['test']);

    test('scales per-100-gram values by grams / 100', () {
      final entry = MealEntry(food: food, grams: 250, category: 'Lunch');
      expect(entry.kcal, 500);
      expect(entry.protein, 25);
      expect(entry.carbs, 50);
      expect(entry.fat, 12.5);
    });

    test('scales small portions consistently', () {
      final entry = MealEntry(food: food, grams: 30, category: 'Snacks');
      expect(entry.kcal, 60);
      expect(entry.protein, 3);
      expect(entry.carbs, 6);
      expect(entry.fat, 1.5);
    });
  });

  group('Portion units', () {
    test('ounces convert to grams and back', () {
      expect(PortionUnit.ounces.toGrams(4), closeTo(113.398, 0.001));
      expect(PortionUnit.ounces.fromGrams(113.398), closeTo(4, 0.0001));
      expect(PortionUnit.grams.toGrams(150), 150);
    });

    test('formats grams and ounces for display', () {
      expect(PortionUnit.grams.formatGrams(150), '150');
      expect(PortionUnit.grams.formatGrams(2.5), '2.5');
      expect(PortionUnit.ounces.formatGrams(113.398), '4');
      expect(PortionUnit.ounces.formatGrams(150), '5.3');
    });
  });

  group('HealthProfile targets', () {
    HealthProfile adult() => HealthProfile()
      ..name = 'Ada'
      ..age = 30
      ..height = 180
      ..weight = 80
      ..activity = 1.55
      ..goal = 'Maintain weight'
      ..formulaSetting = 'Male';

    test('uses Mifflin-St Jeor and the activity factor', () {
      final profile = adult();
      expect(profile.isComplete, isTrue);
      expect(profile.canEstimateCalories, isTrue);
      expect(profile.bmr, 1780);
      expect(profile.maintenanceCalories, closeTo(2759, 0.001));
      expect(profile.calories, 2759);
    });

    test('applies a modest goal adjustment', () {
      final profile = adult();
      profile.goal = 'Lose weight';
      expect(profile.goalAdjustment, -250);
      expect(profile.calories, 2509);
      profile.goal = 'Gain weight';
      expect(profile.goalAdjustment, 200);
      expect(profile.calories, 2959);
    });

    test('uses a transparent 30/40/30 split', () {
      final profile = adult();
      expect(profile.proteinGoal, closeTo(2759 * .30 / 4, 0.001));
      expect(profile.carbsGoal, closeTo(2759 * .40 / 4, 0.001));
      expect(profile.fatGoal, closeTo(2759 * .30 / 9, 0.001));
      final macroCalories =
          profile.proteinGoal * 4 + profile.carbsGoal * 4 + profile.fatGoal * 9;
      expect(macroCalories, closeTo(profile.calories, 0.001));
    });

    test('does not estimate targets under 18', () {
      final profile = adult()..age = 17;
      expect(profile.isComplete, isTrue);
      expect(profile.canEstimateCalories, isFalse);
      expect(profile.calories, 0);
      expect(profile.proteinGoal, 0);
      expect(profile.carbsGoal, 0);
      expect(profile.fatGoal, 0);
    });

    test('requires complete, in-range profile fields', () {
      final profile = HealthProfile();
      expect(profile.isComplete, isFalse);
      profile
        ..name = 'Ada'
        ..age = 30
        ..height = 180
        ..weight = 80
        ..activity = 1.55;
      expect(profile.isComplete, isTrue);
      profile.age = 12;
      expect(profile.isComplete, isFalse);
      profile
        ..age = 30
        ..height = 90;
      expect(profile.isComplete, isFalse);
      profile.height = 180;
      profile.weight = 400;
      expect(profile.isComplete, isFalse);
    });

    test('round-trips through JSON', () {
      final profile = adult()..goalWeight = 75;
      final restored = HealthProfile()
        ..restore(profile.toJson().cast<String, dynamic>());
      expect(restored.name, 'Ada');
      expect(restored.age, 30);
      expect(restored.height, 180);
      expect(restored.weight, 80);
      expect(restored.activity, 1.55);
      expect(restored.goal, 'Maintain weight');
      expect(restored.goalWeight, 75);
      expect(restored.formulaSetting, 'Male');
      expect(restored.calories, profile.calories);
    });

    test('falls back safely from malformed storage', () {
      final profile = HealthProfile()
        ..restore(<String, dynamic>{
          'name': 42,
          'age': 'old',
          'height': -1,
          'weight': 1000,
          'activity': 99,
          'goal': 'Bulk',
          'formulaSetting': 'Unknown',
          'goalWeight': 5,
        });
      expect(profile.name, '');
      expect(profile.age, 0);
      expect(profile.height, -1);
      expect(profile.weight, 1000);
      expect(profile.activity, 1.2);
      expect(profile.goal, 'Maintain weight');
      expect(profile.formulaSetting, 'Average');
      expect(profile.goalWeight, isNull);
      expect(profile.isComplete, isFalse);
    });
  });

  group('Food values and serialization', () {
    test('converts nutrition per serving into per-100-gram values', () {
      final food = Food.fromServing(
        name: 'Custom granola',
        servingGrams: 50,
        calories: 220,
        protein: 5,
        carbs: 30,
        fat: 8,
      );
      expect(food, isNotNull);
      expect(food!.source, FoodSource.custom);
      expect(food.kcal100, closeTo(440, 0.001));
      expect(food.protein100, closeTo(10, 0.001));
      expect(food.carbs100, closeTo(60, 0.001));
      expect(food.fat100, closeTo(16, 0.001));
    });

    test('rejects invalid custom serving data', () {
      expect(
        Food.fromServing(
          name: 'Bad serving',
          servingGrams: 0,
          calories: 100,
          protein: 10,
          carbs: 10,
          fat: 2,
        ),
        isNull,
      );
      expect(
        Food.fromServing(
          name: 'Impossible density',
          servingGrams: 1,
          calories: 5000,
          protein: 10,
          carbs: 10,
          fat: 2,
        ),
        isNull,
      );
      expect(
        Food.fromServing(
          name: '',
          servingGrams: 100,
          calories: 100,
          protein: 10,
          carbs: 10,
          fat: 2,
        ),
        isNull,
      );
    });

    test('rejects physically implausible nutrition', () {
      expect(
        Food.plausiblePer100(kcal: 100, protein: 10, carbs: 10, fat: 10),
        isTrue,
      );
      expect(
        Food.plausiblePer100(kcal: 100, protein: 80, carbs: 80, fat: 80),
        isFalse,
      );
      expect(
        Food.plausiblePer100(kcal: -1, protein: 10, carbs: 10, fat: 10),
        isFalse,
      );
    });

    test('round-trips a food and keeps its source', () {
      const food = Food(
        'Nouri estimate',
        100,
        5,
        10,
        2,
        ['estimate'],
        source: FoodSource.aiEstimate,
      );
      final restored = Food.fromJson(food.toJson());
      expect(restored, isNotNull);
      expect(restored!.name, food.name);
      expect(restored.source, FoodSource.aiEstimate);
      expect(restored.kcal100, 100);
    });

    test('rejects malformed stored food', () {
      expect(Food.fromJson(null), isNull);
      expect(
        Food.fromJson(<String, Object?>{
          'name': '',
          'kcal100': 100,
          'protein100': 1,
          'carbs100': 1,
          'fat100': 1,
        }),
        isNull,
      );
      expect(
        Food.fromJson(<String, Object?>{
          'name': 'Bad',
          'kcal100': double.nan,
          'protein100': 1,
          'carbs100': 1,
          'fat100': 1,
        }),
        isNull,
      );
    });

    test('rejects malformed stored meal entries', () {
      expect(MealEntry.fromJson(null), isNull);
      final food = const Food('Rice', 130, 2.7, 28.2, .3, ['rice']);
      expect(
        MealEntry.fromJson(<String, Object?>{
          'food': food.toJson(),
          'grams': 0,
          'category': 'Lunch',
          'date': DateTime.now().toIso8601String(),
        }),
        isNull,
      );
      expect(
        MealEntry.fromJson(<String, Object?>{
          'food': food.toJson(),
          'grams': 100,
          'category': 'Lunch',
          'date': 'not-a-date',
        }),
        isNull,
      );
    });
  });

  test('default meal follows the time of day', () {
    expect(defaultMealForNow(now: DateTime(2026, 1, 1, 8)), 'Breakfast');
    expect(defaultMealForNow(now: DateTime(2026, 1, 1, 13)), 'Lunch');
    expect(defaultMealForNow(now: DateTime(2026, 1, 1, 19)), 'Dinner');
    expect(defaultMealForNow(now: DateTime(2026, 1, 1, 23)), 'Snacks');
  });
}
