import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MacroTrackApp());
const ink = Color(0xFF1F2B21),
    green = Color(0xFF2E7D32),
    lime = Color(0xFFE8F5E9),
    canvas = Color(0xFFF7FAF6),
    muted = Color(0xFF69766B),
    scanUrl = String.fromEnvironment('MACROS_API_URL', defaultValue: ''),
    scannerAccessCode =
        String.fromEnvironment('SCANNER_ACCESS_TOKEN', defaultValue: '');
const aiName = 'Nouri';
const catalog = <Food>[
  Food('Cooked white rice', 130, 2.7, 28.2, .3,
      ['rice', 'white rice', 'steamed rice']),
  Food('Grilled chicken breast', 165, 31, 0, 3.6,
      ['chicken', 'chicken breast', 'grilled chicken']),
  Food('Cooked egg', 155, 13, 1.1, 11,
      ['egg', 'eggs', 'boiled egg', 'fried egg']),
  Food('Banana', 89, 1.1, 22.8, .3, ['banana']),
  Food('Cooked salmon', 206, 22.1, 0, 12.4, ['salmon', 'fish']),
  Food('Cooked oatmeal', 71, 2.5, 12, 1.5,
      ['oatmeal', 'porridge', 'rolled oats']),
  Food('Baked potato', 93, 2.5, 21, .1, ['potato', 'baked potato']),
  Food('Cooked broccoli', 35, 2.4, 7.2, .4, ['broccoli']),
  Food('Whole wheat bread', 247, 13, 41, 4.2,
      ['bread', 'toast', 'whole wheat bread']),
  Food('Avocado', 160, 2, 8.5, 14.7, ['avocado', 'avocado slices']),
  Food('Greek yogurt, plain', 97, 9, 3.9, 5, ['greek yogurt', 'yogurt']),
  Food('Tomato', 18, .9, 3.9, .2, ['tomato', 'tomatoes']),
  Food('Lettuce', 15, 1.4, 2.9, .2, ['lettuce', 'salad greens']),
  Food('Pork adobo', 210, 20, 4, 12, ['adobo', 'pork adobo']),
];
String norm(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
Food? matchFood(String text) {
  final q = norm(text);
  for (final f in catalog) {
    if (f.aliases
        .any((a) => q == norm(a) || q.contains(norm(a)) || norm(a).contains(q)))
      return f;
  }
  return null;
}

Food? aiFoodFromResult(String name, Object? rawNutrition) {
  if (rawNutrition is! Map) return null;
  final calories = (rawNutrition['calories_kcal'] as num?)?.toDouble();
  final protein = (rawNutrition['protein_g'] as num?)?.toDouble();
  final carbs = (rawNutrition['carbs_g'] as num?)?.toDouble();
  final fat = (rawNutrition['fat_g'] as num?)?.toDouble();
  if (calories == null || protein == null || carbs == null || fat == null) {
    return null;
  }
  final values = [calories, protein, carbs, fat];
  if (values.any((value) => !value.isFinite || value < 0) ||
      calories > 950 ||
      protein > 100 ||
      carbs > 100 ||
      fat > 100 ||
      protein + carbs + fat > 101) {
    return null;
  }
  return Food(name, calories, protein, carbs, fat, [name], isAiEstimate: true);
}

String? imageMimeType(XFile file) {
  const supported = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };
  final fromPicker = file.mimeType?.split(';').first.trim().toLowerCase();
  if (fromPicker != null && supported.contains(fromPicker)) return fromPicker;
  final extension = file.name.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => null,
  };
}

class Food {
  const Food(this.name, this.kcal100, this.protein100, this.carbs100,
      this.fat100, this.aliases,
      {this.isAiEstimate = false});
  final String name;
  final double kcal100, protein100, carbs100, fat100;
  final List<String> aliases;
  final bool isAiEstimate;
}

class MealEntry {
  MealEntry(
      {required this.food,
      required this.grams,
      required this.category,
      DateTime? date})
      : date = date ?? DateTime.now();
  final Food food;
  final double grams;
  final String category;
  final DateTime date;
  double get kcal => food.kcal100 * grams / 100;
  double get protein => food.protein100 * grams / 100;
  double get carbs => food.carbs100 * grams / 100;
  double get fat => food.fat100 * grams / 100;
}

class HealthProfile {
  String name = '';
  String formulaSetting = 'Average';
  String goal = 'Maintain weight';
  int age = 0;
  double height = 0, weight = 0, activity = 1.2;
  double? goalWeight;

  bool get isComplete =>
      name.trim().isNotEmpty &&
      age >= 13 &&
      age <= 110 &&
      height >= 100 &&
      height <= 250 &&
      weight >= 30 &&
      weight <= 350 &&
      const ['Lose weight', 'Maintain weight', 'Gain weight'].contains(goal) &&
      const ['Female', 'Male', 'Average'].contains(formulaSetting) &&
      const [1.2, 1.375, 1.55, 1.725].contains(activity);
  bool get canEstimateCalories => isComplete && age >= 18;
  double get maintenanceCalories => bmr * activity;
  double get bmr =>
      10 * weight +
      6.25 * height -
      5 * age +
      switch (formulaSetting) {
        'Female' => -161,
        'Male' => 5,
        _ => -78,
      };
  double get goalAdjustment => switch (goal) {
        'Lose weight' => -250,
        'Gain weight' => 200,
        _ => 0,
      };
  double get calories => canEstimateCalories
      ? (maintenanceCalories + goalAdjustment).clamp(0, 10000).roundToDouble()
      : 0;
  double get proteinGoal => calories * .30 / 4;
  double get carbsGoal => calories * .40 / 4;
  double get fatGoal => calories * .30 / 9;

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
    name = data['name'] as String? ?? '';
    age = (data['age'] as num?)?.toInt() ?? 0;
    height = (data['height'] as num?)?.toDouble() ?? 0;
    weight = (data['weight'] as num?)?.toDouble() ?? 0;
    final savedFormula = data['formulaSetting'] as String?;
    formulaSetting = const ['Female', 'Male', 'Average'].contains(savedFormula)
        ? savedFormula!
        : 'Average';
    final savedActivity = (data['activity'] as num?)?.toDouble();
    activity = const [1.2, 1.375, 1.55, 1.725].contains(savedActivity)
        ? savedActivity!
        : 1.2;
    final savedGoal = data['goal'] as String?;
    goal = const ['Lose weight', 'Maintain weight', 'Gain weight']
            .contains(savedGoal)
        ? savedGoal!
        : 'Maintain weight';
    goalWeight = (data['goalWeight'] as num?)?.toDouble();
  }
}

class MacroTrackApp extends StatefulWidget {
  const MacroTrackApp({super.key});
  @override
  State<MacroLensApp> createState() => _MacroLensAppState();
}

class _MacroLensAppState extends State<MacroLensApp> {
  final store = LocalStore();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final entries = <MealEntry>[];
  HealthProfile profile = HealthProfile();
  bool signedIn = false;
  bool sessionLoaded = false;
  bool profileConfigured = false;
  bool storageWarningShown = false;
  int tab = 0;
  DateTime selectedDay = dateOnly(DateTime.now());
  late final ThemeData appTheme = buildAppTheme();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await store.load();
    if (!mounted) return;
    setState(() {
      signedIn = data.signedIn;
      profile = data.profile;
      profileConfigured = profile.isComplete;
      entries
        ..clear()
        ..addAll(data.entries);
      sessionLoaded = true;
    });
  }

  Future<void> _continueDemo(String? displayName) async {
    await store.saveSignedIn(true);
    final trimmed = (displayName ?? '').trim();
    if (!profileConfigured && trimmed.isNotEmpty) {
      profile.name = trimmed;
    }
    if (!mounted) return;
    setState(() => signedIn = true);
  }

  Future<void> _saveProfile() async {
    await store.saveProfile(profile);
    if (!mounted) return;
    setState(() => profileConfigured = profile.isComplete);
  }

  Future<void> _signOut() async {
    try {
      await store.saveSignedIn(false);
    } catch (_) {
      // Still end the in-app session even if the device flag cannot be saved.
    }
    if (!mounted) return;
    setState(() {
      signedIn = false;
      tab = 0;
      selectedDay = dateOnly(DateTime.now());
    });
  }

  void _addEntry(MealEntry entry) {
    setState(() {
      entries.insert(0, entry);
      selectedDay = dateOnly(entry.date);
      tab = 0;
    });
    _persistLog();
    _showSnack(
      'Logged ${entry.food.name}',
      duration: const Duration(seconds: 3),
      persist: false,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => _undoEntry(entry),
      ),
    );
  }

  void _removeEntry(MealEntry entry) {
    final index = entries.indexOf(entry);
    if (index == -1) return;
    setState(() => entries.removeAt(index));
    _persistLog();
    _showSnack(
      'Removed ${entry.food.name}',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => _restoreEntry(entry, index),
      ),
    );
  }

  void _undoEntry(MealEntry entry) {
    if (entries.contains(entry)) {
      setState(() => entries.remove(entry));
      _persistLog();
    }
  }

  void _restoreEntry(MealEntry entry, int index) {
    if (entries.contains(entry)) return;
    setState(() {
      entries.insert(index > entries.length ? entries.length : index, entry);
    });
    _persistLog();
  }

  Future<void> _persistLog() async {
    try {
      await store.saveLog(entries);
      storageWarningShown = false;
    } catch (_) {
      if (mounted && !storageWarningShown) {
        storageWarningShown = true;
        _showSnack(
          'Meal saved for this session, but this device’s storage could not be updated.',
        );
      }
    }
  }

  Future<void> _clearHistory() async {
    try {
      await store.clearLog();
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not clear meal history. Please try again.');
      return;
    }
    if (!mounted) return;
    setState(() => entries.clear());
    _showSnack('Meal history cleared');
  }

  void _showSnack(
    String message, {
    SnackBarAction? action,
    Duration? duration,
    bool? persist,
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          duration: duration ?? const Duration(seconds: 4),
          persist: persist,
        ),
      );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MacroLens',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: messengerKey,
        theme: appTheme,
        home: !sessionLoaded
            ? const _LoadingScreen()
            : signedIn
                ? !profileConfigured
                    ? ProfileEditorPage(
                        profile: profile,
                        isSetup: true,
                        onSave: _saveProfile,
                      )
                    : Scaffold(
                        body: SafeArea(
                          bottom: false,
                          child: IndexedStack(
                            index: tab,
                            children: [
                              TodayPage(
                                day: selectedDay,
                                entries: entries,
                                profile: profile,
                                onDay: (day) =>
                                    setState(() => selectedDay = dateOnly(day)),
                                onAdd: _addEntry,
                                onRemove: _removeEntry,
                                onScan: () => setState(() => tab = 1),
                                onShowLog: () => setState(() => tab = 2),
                              ),
                              ScannerPage(onAdd: _addEntry),
                              FoodLogPage(
                                day: selectedDay,
                                entries: entries,
                                profile: profile,
                                onDay: (day) =>
                                    setState(() => selectedDay = dateOnly(day)),
                                onScan: () => setState(() => tab = 1),
                                onAdd: _addEntry,
                                onRemove: _removeEntry,
                              ),
                              ProfilePage(
                                profile: profile,
                                onSaved: _saveProfile,
                                onSignOut: _signOut,
                                onClearHistory: _clearHistory,
                                hasHistory: entries.isNotEmpty,
                              ),
                            ],
                          ),
                        ),
                        bottomNavigationBar: NavigationBar(
                          selectedIndex: tab,
                          onDestinationSelected: (index) =>
                              setState(() => tab = index),
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Icons.home_outlined),
                              selectedIcon: Icon(Icons.home_rounded),
                              label: 'Today',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.document_scanner_outlined),
                              selectedIcon:
                                  Icon(Icons.document_scanner_rounded),
                              label: 'Scanner',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.restaurant_menu_outlined),
                              selectedIcon: Icon(Icons.restaurant_menu_rounded),
                              label: 'Food log',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.person_outline_rounded),
                              selectedIcon: Icon(Icons.person_rounded),
                              label: 'Profile',
                            ),
                          ],
                        ),
                      )
                : LoginPage(onContinue: _continueDemo),
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.center_focus_strong_rounded,
                color: AppColors.green,
                size: 44,
              ),
              SizedBox(height: 12),
              Text(
                'MacroLens',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 14),
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      );
}
