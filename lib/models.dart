import 'dart:math' as math;

/// Where a food's per-100-gram nutrition values came from.
enum FoodSource { catalog, aiEstimate, custom }

const mealCategories = <String>['Breakfast', 'Lunch', 'Dinner', 'Snacks'];

const gramsPerOunce = 28.349523125;

/// A food with nutrition values expressed per 100 edible grams.
class Food {
  const Food(
    this.name,
    this.kcal100,
    this.protein100,
    this.carbs100,
    this.fat100,
    this.aliases, {
    this.source = FoodSource.catalog,
  });

  final String name;
  final double kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;
  final List<String> aliases;
  final FoodSource source;

  bool get isAiEstimate => source == FoodSource.aiEstimate;
  bool get isCustom => source == FoodSource.custom;

  double kcalFor(double grams) => kcal100 * grams / 100;
  double proteinFor(double grams) => protein100 * grams / 100;
  double carbsFor(double grams) => carbs100 * grams / 100;
  double fatFor(double grams) => fat100 * grams / 100;

  /// True when a per-100-gram nutrition set is finite and physically plausible.
  ///
  /// The small allowance above 100 g for protein + carbs + fat covers label
  /// rounding. It is deliberately stricter than "any number the model returns".
  static bool plausiblePer100({
    required double kcal,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    final values = [kcal, protein, carbs, fat];
    if (values.any((value) => !value.isFinite || value < 0)) return false;
    return kcal <= 900 &&
        protein <= 100 &&
        carbs <= 100 &&
        fat <= 100 &&
        protein + carbs + fat <= 105;
  }

  static bool validName(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= 120 &&
        !RegExp('[\\x00-\\x1F\\x7F]').hasMatch(trimmed);
  }

  /// Converts everyday "nutrition per serving" input into per-100-g values.
  ///
  /// Returns null when the serving size or nutrition is invalid, so the UI can
  /// show a plain validation message instead of storing impossible values.
  static Food? fromServing({
    required String name,
    required double servingGrams,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    if (!validName(name) ||
        !servingGrams.isFinite ||
        servingGrams < 1 ||
        servingGrams > 5000) {
      return null;
    }
    final values = <double>[calories, protein, carbs, fat];
    if (values.any((value) => !value.isFinite || value < 0)) return null;
    final factor = 100 / servingGrams;
    final kcal100 = calories * factor;
    final protein100 = protein * factor;
    final carbs100 = carbs * factor;
    final fat100 = fat * factor;
    if (!plausiblePer100(
      kcal: kcal100,
      protein: protein100,
      carbs: carbs100,
      fat: fat100,
    )) {
      return null;
    }
    return Food(
      name.trim(),
      kcal100,
      protein100,
      carbs100,
      fat100,
      <String>[name.trim()],
      source: FoodSource.custom,
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'kcal100': kcal100,
        'protein100': protein100,
        'carbs100': carbs100,
        'fat100': fat100,
        'aliases': aliases,
        'source': source.name,
      };

  static Food? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final rawName = raw['name'];
    final kcal = (raw['kcal100'] as num?)?.toDouble();
    final protein = (raw['protein100'] as num?)?.toDouble();
    final carbs = (raw['carbs100'] as num?)?.toDouble();
    final fat = (raw['fat100'] as num?)?.toDouble();
    if (rawName is! String || !validName(rawName)) return null;
    if (kcal == null ||
        protein == null ||
        carbs == null ||
        fat == null ||
        !plausiblePer100(
          kcal: kcal,
          protein: protein,
          carbs: carbs,
          fat: fat,
        )) {
      return null;
    }
    final rawAliases = raw['aliases'];
    final aliases = rawAliases is List
        ? rawAliases
            .whereType<String>()
            .where((a) => a.trim().isNotEmpty)
            .toList()
        : <String>[];
    final rawSource = raw['source'];
    final source = FoodSource.values.firstWhere(
      (candidate) => candidate.name == rawSource,
      orElse: () => FoodSource.catalog,
    );
    return Food(
      rawName.trim(),
      kcal,
      protein,
      carbs,
      fat,
      aliases,
      source: source,
    );
  }
}

/// One logged food portion.
class MealEntry {
  MealEntry({
    required this.food,
    required this.grams,
    required this.category,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  final Food food;
  final double grams;
  final String category;
  final DateTime date;

  double get kcal => food.kcalFor(grams);
  double get protein => food.proteinFor(grams);
  double get carbs => food.carbsFor(grams);
  double get fat => food.fatFor(grams);

  Map<String, Object?> toJson() => {
        'food': food.toJson(),
        'grams': grams,
        'category': category,
        'date': date.toIso8601String(),
      };

  static MealEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final food = Food.fromJson(raw['food']);
    final grams = (raw['grams'] as num?)?.toDouble();
    final rawCategory = raw['category'];
    final rawDate = raw['date'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (food == null ||
        grams == null ||
        !grams.isFinite ||
        grams <= 0 ||
        grams > 5000 ||
        date == null) {
      return null;
    }
    final category =
        mealCategories.contains(rawCategory) ? rawCategory as String : 'Snacks';
    return MealEntry(
      food: food,
      grams: grams,
      category: category,
      date: date,
    );
  }
}

/// Profile data and the transparent, rough adult target calculation.
class HealthProfile {
  String name = '';
  String formulaSetting = 'Average';
  String goal = 'Maintain weight';
  int age = 0;
  double height = 0;
  double weight = 0;
  double activity = 1.2;
  double? goalWeight;

  static const goals = <String>[
    'Lose weight',
    'Maintain weight',
    'Gain weight',
  ];
  static const formulaSettings = <String>['Female', 'Male', 'Average'];
  static const activityLevels = <double>[1.2, 1.375, 1.55, 1.725];

  static const proteinShare = 0.30;
  static const carbsShare = 0.40;
  static const fatShare = 0.30;

  bool get isComplete =>
      name.trim().isNotEmpty &&
      name.trim().length <= 60 &&
      age >= 13 &&
      age <= 110 &&
      height >= 100 &&
      height <= 250 &&
      weight >= 30 &&
      weight <= 350 &&
      goals.contains(goal) &&
      formulaSettings.contains(formulaSetting) &&
      activityLevels.contains(activity) &&
      (goalWeight == null || (goalWeight! >= 30 && goalWeight! <= 350));

  bool get isAdult => age >= 18;
  bool get canEstimateCalories => isComplete && isAdult;

  double get formulaConstant => switch (formulaSetting) {
        'Female' => -161,
        'Male' => 5,
        _ => -78,
      };

  double get bmr => 10 * weight + 6.25 * height - 5 * age + formulaConstant;

  double get maintenanceCalories => bmr * activity;

  double get goalAdjustment => switch (goal) {
        'Lose weight' => -250,
        'Gain weight' => 200,
        _ => 0,
      };

  double get calories => canEstimateCalories
      ? (maintenanceCalories + goalAdjustment).clamp(0, 10000).roundToDouble()
      : 0;

  double get proteinGoal => calories * proteinShare / 4;
  double get carbsGoal => calories * carbsShare / 4;
  double get fatGoal => calories * fatShare / 9;

  String get activityLabel => switch (activity) {
        1.2 => 'Mostly sitting',
        1.375 => 'Light activity',
        1.55 => 'Moderate activity',
        _ => 'Very active',
      };

  Map<String, Object?> toJson() => {
        'name': name.trim(),
        'age': age,
        'height': height,
        'weight': weight,
        'formulaSetting': formulaSetting,
        'activity': activity,
        'goal': goal,
        'goalWeight': goalWeight,
      };

  void restore(Map<String, dynamic> data) {
    name = data['name'] is String ? (data['name'] as String).trim() : '';
    age = _readInt(data['age']) ?? 0;
    height = _readDouble(data['height']) ?? 0;
    weight = _readDouble(data['weight']) ?? 0;

    final savedFormula = data['formulaSetting'];
    formulaSetting = formulaSettings.contains(savedFormula)
        ? savedFormula as String
        : 'Average';

    final savedActivity = _readDouble(data['activity']);
    activity = savedActivity != null && activityLevels.contains(savedActivity)
        ? savedActivity
        : 1.2;

    final savedGoal = data['goal'];
    goal = goals.contains(savedGoal) ? savedGoal as String : 'Maintain weight';

    final savedGoalWeight = _readDouble(data['goalWeight']);
    goalWeight = savedGoalWeight != null &&
            savedGoalWeight >= 30 &&
            savedGoalWeight <= 350
        ? savedGoalWeight
        : null;
  }

  static double? _readDouble(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    return null;
  }

  static int? _readInt(Object? value) {
    if (value is num && value.isFinite) return value.toInt();
    return null;
  }
}

/// Grams/ounces handling shared by the scanner and manual entry.
enum PortionUnit {
  grams('g', 'grams'),
  ounces('oz', 'ounces');

  const PortionUnit(this.symbol, this.label);

  final String symbol;
  final String label;

  double toGrams(double amount) =>
      this == PortionUnit.ounces ? amount * gramsPerOunce : amount;

  double fromGrams(double grams) =>
      this == PortionUnit.ounces ? grams / gramsPerOunce : grams;

  /// Formats an amount that is currently expressed in this unit.
  String formatAmount(double amount) {
    if (this == PortionUnit.ounces) return _trim(amount, 1);
    return amount >= 10 ? amount.round().toString() : _trim(amount, 1);
  }

  /// Formats a gram value after converting it into this unit.
  String formatGrams(double grams) => formatAmount(fromGrams(grams));

  static String _trim(double value, int digits) {
    final text = value.toStringAsFixed(digits);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
}

/// Best-guess meal for a new entry based on the current time.
String defaultMealForNow({DateTime? now}) {
  final hour = (now ?? DateTime.now()).hour;
  if (hour < 11) return 'Breakfast';
  if (hour < 16) return 'Lunch';
  if (hour < 21) return 'Dinner';
  return 'Snacks';
}

/// Keeps a scanned portion displayable even if a model returns a narrow range.
double clampPortion(double value) => math.min(5000, math.max(1, value));
