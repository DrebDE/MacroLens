import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macro_scan/main.dart';
import 'package:macro_scan/models.dart';
import 'package:macro_scan/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

HealthProfile completedProfile() => HealthProfile()
  ..name = 'Ada'
  ..age = 30
  ..height = 180
  ..weight = 80
  ..activity = 1.55
  ..goal = 'Maintain weight'
  ..formulaSetting = 'Male';

Future<void> configurePhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const MacroLensApp());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('demo sign-in, profile setup, logging, and restart',
      (tester) async {
    await configurePhone(tester);
    await pumpApp(tester);

    expect(find.text('Sign in to MacroLens'), findsOneWidget);
    final loginFields = find.byType(TextFormField);
    expect(loginFields, findsNWidgets(2));
    await tester.enterText(loginFields.at(0), 'demo@example.com');
    await tester.enterText(loginFields.at(1), 'demo1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Set up your profile'), findsOneWidget);
    final setupFields = find.byType(TextFormField);
    expect(setupFields, findsNWidgets(4));
    await tester.enterText(setupFields.at(0), 'Ada');
    await tester.enterText(setupFields.at(1), '30');
    await tester.enterText(setupFields.at(2), '180');
    await tester.enterText(setupFields.at(3), '80');
    await tester.tap(find.widgetWithText(FilledButton, 'Save profile'));
    await tester.pumpAndSettle();

    expect(find.text('DAILY ENERGY'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LocalStore.demoSessionKey), isTrue);

    await tester.tap(find.text('Log food'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a food'), findsOneWidget);

    await tester.tap(find.text('Choose a food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cooked white rice').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Cooked white rice'), findsOneWidget);
    expect(prefs.getString(LocalStore.logKey), isNotNull);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Food log'), findsWidgets);
    expect(find.text('Cooked white rice'), findsOneWidget);

    // Simulate closing and reopening the app.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp(tester);
    expect(find.text('Sign in to MacroLens'), findsNothing);
    expect(find.text('Set up your profile'), findsNothing);
    expect(find.text('DAILY ENERGY'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Cooked white rice'), findsOneWidget);
  });

  testWidgets('scanner UI has no connection section or URL', (tester) async {
    await configurePhone(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalStore.demoSessionKey: true,
      LocalStore.profileKey: jsonEncode(completedProfile().toJson()),
    });
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.document_scanner_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Scan food'), findsOneWidget);
    expect(find.text('Scan with Nouri'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Scanner connection'), findsNothing);
    expect(find.textContaining('http://'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('Access code'), findsNothing);
    expect(find.textContaining('confidence'), findsNothing);
  });

  testWidgets('under-18 profile shows no calorie target', (tester) async {
    await configurePhone(tester);
    final teen = HealthProfile()
      ..name = 'Sam'
      ..age = 16
      ..height = 165
      ..weight = 55
      ..activity = 1.2;
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalStore.demoSessionKey: true,
      LocalStore.profileKey: jsonEncode(teen.toJson()),
    });
    await pumpApp(tester);

    expect(find.text('DAILY ENERGY'), findsOneWidget);
    expect(find.text('Today’s energy'), findsOneWidget);
    expect(find.textContaining('kcal logged today'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Daily goals aren’t available'), findsOneWidget);
    expect(find.text('DAILY CALORIE GOAL'), findsNothing);
  });

  testWidgets('forgot password explains the demo reset flow', (tester) async {
    await configurePhone(tester);
    await pumpApp(tester);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      'demo@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.textContaining('No reset email was sent'), findsOneWidget);
    expect(find.text('Reset your password'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to MacroLens'), findsOneWidget);
  });

  testWidgets('registration collects full name and requires terms',
      (tester) async {
    await configurePhone(tester);
    await pumpApp(tester);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byType(Checkbox), findsOneWidget);

    final createButton = find.widgetWithText(FilledButton, 'Create my account');
    expect(tester.widget<FilledButton>(createButton).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).at(0), 'Alex Smith');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(createButton).onPressed, isNotNull);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    expect(find.text('Set up your profile'), findsOneWidget);
  });

  testWidgets('profile uses plain goal labels instead of formulas',
      (tester) async {
    await configurePhone(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalStore.demoSessionKey: true,
      LocalStore.profileKey: jsonEncode(completedProfile().toJson()),
    });
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('DAILY CALORIE GOAL'), findsOneWidget);
    expect(find.text('Sex used for estimate'), findsOneWidget);
    expect(find.textContaining('Mifflin'), findsNothing);
    expect(find.textContaining('BMR'), findsNothing);
    expect(find.textContaining('30%'), findsNothing);
    expect(find.textContaining('How this is estimated'), findsNothing);
    expect(find.textContaining('Protein'), findsWidgets);
  });

  testWidgets('custom food converts serving nutrition before logging',
      (tester) async {
    await configurePhone(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalStore.demoSessionKey: true,
      LocalStore.profileKey: jsonEncode(completedProfile().toJson()),
    });
    await pumpApp(tester);

    await tester.tap(find.text('Log food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom food'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(7));
    await tester.enterText(fields.at(0), 'Homemade soup');
    await tester.enterText(fields.at(1), '250');
    await tester.enterText(fields.at(2), '300');
    await tester.enterText(fields.at(3), '15');
    await tester.enterText(fields.at(4), '30');
    await tester.enterText(fields.at(5), '12');
    await tester.enterText(fields.at(6), '200');
    await tester.pumpAndSettle();

    expect(find.text('Nutrition'), findsOneWidget);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Homemade soup'), findsOneWidget);
  });

  testWidgets('date navigation shows the selected day entries', (tester) async {
    await configurePhone(tester);
    final store = LocalStore();
    await store.saveSignedIn(true);
    await store.saveProfile(completedProfile());
    final today = DateTime.now();
    await store.saveLog(<MealEntry>[
      MealEntry(
        food: const Food('Today rice', 130, 2.7, 28.2, .3, ['rice']),
        grams: 100,
        category: 'Lunch',
        date: today,
      ),
      MealEntry(
        food: const Food('Yesterday soup', 60, 3, 8, 2, ['soup']),
        grams: 200,
        category: 'Dinner',
        date: today.subtract(const Duration(days: 1)),
      ),
    ]);
    await pumpApp(tester);

    expect(find.text('Today rice'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday soup'), findsOneWidget);
    expect(find.text('Today rice'), findsNothing);
  });
}
