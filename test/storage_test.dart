import 'package:flutter_test/flutter_test.dart';
import 'package:macro_scan/models.dart';
import 'package:macro_scan/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('round-trips the demo session, profile, and meal log', () async {
    final store = LocalStore();
    await store.saveSignedIn(true);
    await store.saveProfile(
      HealthProfile()
        ..name = 'Ada'
        ..age = 31
        ..height = 172
        ..weight = 68.5
        ..activity = 1.375
        ..goal = 'Lose weight'
        ..goalWeight = 65
        ..formulaSetting = 'Female',
    );
    final rice = MealEntry(
      food: const Food('Cooked white rice', 130, 2.7, 28.2, .3, ['rice']),
      grams: 150,
      category: 'Lunch',
      date: DateTime(2026, 11, 6, 12, 30),
    );
    final ai = MealEntry(
      food: const Food(
        'Nouri dish',
        120,
        8,
        10,
        4,
        ['Nouri dish'],
        source: FoodSource.aiEstimate,
      ),
      grams: 220,
      category: 'Dinner',
      date: DateTime(2026, 11, 6, 19, 10),
    );
    await store.saveLog(<MealEntry>[rice, ai]);

    final data = await LocalStore().load();
    expect(data.signedIn, isTrue);
    expect(data.profile.name, 'Ada');
    expect(data.profile.age, 31);
    expect(data.profile.height, 172);
    expect(data.profile.weight, 68.5);
    expect(data.profile.activity, 1.375);
    expect(data.profile.goal, 'Lose weight');
    expect(data.profile.goalWeight, 65);
    expect(data.profile.formulaSetting, 'Female');
    expect(data.entries, hasLength(2));
    expect(data.entries[0].food.name, 'Cooked white rice');
    expect(data.entries[0].grams, 150);
    expect(data.entries[0].category, 'Lunch');
    expect(data.entries[0].date, DateTime(2026, 11, 6, 12, 30));
    expect(data.entries[1].food.source, FoodSource.aiEstimate);
    expect(data.entries[1].grams, 220);
  });

  test('signing out clears only the session flag', () async {
    final store = LocalStore();
    await store.saveSignedIn(true);
    await store.saveProfile(
      HealthProfile()
        ..name = 'Ada'
        ..age = 30
        ..height = 170
        ..weight = 65
        ..activity = 1.2,
    );
    await store.saveLog(<MealEntry>[
      MealEntry(
        food: const Food('Banana', 89, 1.1, 22.8, .3, ['banana']),
        grams: 100,
        category: 'Snacks',
      ),
    ]);

    await store.saveSignedIn(false);
    final data = await LocalStore().load();
    expect(data.signedIn, isFalse);
    expect(data.profile.name, 'Ada');
    expect(data.entries, hasLength(1));
  });

  test('clearing the log leaves the profile intact', () async {
    final store = LocalStore();
    await store.saveProfile(HealthProfile()..name = 'Ada');
    await store.saveLog(<MealEntry>[
      MealEntry(
        food: const Food('Banana', 89, 1.1, 22.8, .3, ['banana']),
        grams: 100,
        category: 'Snacks',
      ),
    ]);
    await store.clearLog();
    final data = await LocalStore().load();
    expect(data.profile.name, 'Ada');
    expect(data.entries, isEmpty);
  });

  test('ignores corrupt local JSON instead of crashing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalStore.demoSessionKey: true,
      LocalStore.profileKey: '{bad json',
      LocalStore.logKey: 'not a list',
    });
    final data = await LocalStore().load();
    expect(data.signedIn, isTrue);
    expect(data.profile.isComplete, isFalse);
    expect(data.entries, isEmpty);
  });

  test('drops invalid stored entries but keeps valid ones', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalStore.logKey:
          '[{"food":{"name":"","kcal100":1,"protein100":1,"carbs100":1,"fat100":1},"grams":100,"category":"Lunch","date":"2026-11-06T12:00:00.000"},{"food":{"name":"Rice","kcal100":130,"protein100":2.7,"carbs100":28.2,"fat100":0.3,"aliases":["rice"],"source":"catalog"},"grams":100,"category":"Dinner","date":"2026-11-06T19:00:00.000"}]',
    });
    final data = await LocalStore().load();
    expect(data.entries, hasLength(1));
    expect(data.entries.single.food.name, 'Rice');
    expect(data.entries.single.category, 'Dinner');
  });
}
