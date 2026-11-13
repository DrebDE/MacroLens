import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macro_scan/catalog.dart';
import 'package:macro_scan/main.dart';
import 'package:macro_scan/models.dart';
import 'package:macro_scan/scanner_service.dart';
import 'package:macro_scan/screens/food_log_page.dart';
import 'package:macro_scan/screens/food_picker_page.dart';
import 'package:macro_scan/screens/forgot_password_page.dart';
import 'package:macro_scan/screens/legal_page.dart';
import 'package:macro_scan/screens/login_page.dart';
import 'package:macro_scan/screens/manual_add_page.dart';
import 'package:macro_scan/screens/profile_page.dart';
import 'package:macro_scan/screens/scanner_page.dart';
import 'package:macro_scan/screens/today_page.dart';
import 'package:macro_scan/storage.dart';
import 'package:macro_scan/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

HealthProfile adultProfile() => HealthProfile()
  ..name = 'Alexandra Montgomery'
  ..age = 34
  ..height = 181
  ..weight = 84.5
  ..activity = 1.55
  ..goal = 'Lose weight'
  ..goalWeight = 78
  ..formulaSetting = 'Female';

HealthProfile teenProfile() => HealthProfile()
  ..name = 'Sam'
  ..age = 16
  ..height = 165
  ..weight = 55
  ..activity = 1.2;

List<MealEntry> sampleEntries() {
  final today = DateTime.now();
  return <MealEntry>[
    MealEntry(
      food: catalog.first,
      grams: 180,
      category: 'Lunch',
      date: today,
    ),
    MealEntry(
      food: const Food(
        'A very long custom food name that should wrap instead of overflowing',
        220,
        12,
        24,
        8,
        <String>['custom'],
        source: FoodSource.custom,
      ),
      grams: 1234,
      category: 'Dinner',
      date: today,
    ),
  ];
}

Future<void> pumpSurface(
  WidgetTester tester,
  Widget page, {
  bool pageIsScaffold = false,
  double width = 320,
  double height = 800,
  double textScale = 1.3,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: pageIsScaffold ? page : Scaffold(body: page),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> scrollToBottom(WidgetTester tester) async {
  final list = find.byType(ListView);
  final scrollable = find.byType(Scrollable);
  if (list.evaluate().isNotEmpty) {
    await tester.drag(list.first, const Offset(0, -1600));
  } else if (scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable.first, const Offset(0, -1600));
  } else {
    return;
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Today fits a narrow phone at large text', (tester) async {
    await pumpSurface(
      tester,
      TodayPage(
        day: DateTime.now(),
        entries: sampleEntries(),
        profile: adultProfile(),
        onDay: (_) {},
        onAdd: (_) {},
        onRemove: (_) {},
        onScan: () {},
        onShowLog: () {},
      ),
      height: 700,
    );
    await scrollToBottom(tester);
  });

  testWidgets('Food log fits a narrow phone at large text', (tester) async {
    await pumpSurface(
      tester,
      FoodLogPage(
        day: DateTime.now(),
        entries: sampleEntries(),
        profile: adultProfile(),
        onDay: (_) {},
        onAdd: (_) {},
        onRemove: (_) {},
      ),
      height: 700,
    );
    await scrollToBottom(tester);
  });

  testWidgets('Profile fits a narrow phone at large text', (tester) async {
    await pumpSurface(
      tester,
      ProfilePage(
        profile: adultProfile(),
        onSaved: () async {},
        onSignOut: () {},
        onClearHistory: () async {},
        hasHistory: true,
      ),
      height: 700,
    );
    await scrollToBottom(tester);
  });

  testWidgets('under-18 profile fits without target cards', (tester) async {
    await pumpSurface(
      tester,
      ProfilePage(
        profile: teenProfile(),
        onSaved: () async {},
        onSignOut: () {},
        onClearHistory: () async {},
        hasHistory: false,
      ),
      height: 1200,
    );
    expect(find.text('Daily goals aren’t available'), findsOneWidget);
    expect(find.text('DAILY CALORIE GOAL'), findsNothing);
    await scrollToBottom(tester);
  });

  testWidgets('Scanner fits a narrow phone at large text', (tester) async {
    await pumpSurface(
      tester,
      ScannerPage(onAdd: (_) {}),
      height: 700,
    );
    await scrollToBottom(tester);
  });

  testWidgets('scanner confirmation fits a narrow phone at large text',
      (tester) async {
    const estimate = ScanEstimate(
      foodName: 'Grilled chicken breast',
      confidence: .82,
      portionGuessG: 180,
      portionLowG: 140,
      portionHighG: 230,
      aiFood: Food(
        'Grilled chicken breast',
        165,
        31,
        0,
        3.6,
        <String>['chicken'],
        source: FoodSource.aiEstimate,
      ),
    );
    await pumpSurface(
      tester,
      ScannerPage(
        onAdd: (_) {},
        initialEstimate: estimate,
        initialFood: const Food(
          'Cooked white rice',
          130,
          2.7,
          28.2,
          .3,
          <String>['rice'],
        ),
      ),
      height: 700,
    );
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -2200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Estimated food'), findsOneWidget);
    expect(find.text('Cooked white rice'), findsOneWidget);
    expect(find.text('Estimated portion'), findsOneWidget);
    expect(find.textContaining('confidence'), findsNothing);
  });

  testWidgets('Manual entry fits a narrow phone at large text', (tester) async {
    await pumpSurface(
      tester,
      ManualAddPage(day: DateTime.now(), initialMeal: 'Lunch'),
      pageIsScaffold: true,
      height: 700,
    );
    await scrollToBottom(tester);
    await tester.tap(find.text('Custom food'));
    await tester.pumpAndSettle();
    await scrollToBottom(tester);
  });

  testWidgets('Food picker fits a narrow phone at large text', (tester) async {
    await pumpSurface(
      tester,
      FoodPickerPage(
        aiEstimate: const Food(
          'Nouri mixed dish estimate',
          150,
          8,
          18,
          5,
          <String>['dish'],
          source: FoodSource.aiEstimate,
        ),
      ),
      pageIsScaffold: true,
      height: 700,
    );
    await scrollToBottom(tester);
  });

  testWidgets('Profile editor fits a narrow phone at large text',
      (tester) async {
    await pumpSurface(
      tester,
      ProfileEditorPage(
        profile: adultProfile(),
        onSave: () async {},
      ),
      pageIsScaffold: true,
      height: 700,
    );
    await scrollToBottom(tester);
  });

  testWidgets('Login fits a narrow phone at large text', (tester) async {
    await pumpSurface(
      tester,
      LoginPage(onContinue: (_) async {}),
      pageIsScaffold: true,
      height: 700,
    );
    await scrollToBottom(tester);
  });

  testWidgets('Registration fits a narrow phone at large text', (tester) async {
    await pumpSurface(
      tester,
      LoginPage(onContinue: (_) async {}),
      pageIsScaffold: true,
      height: 700,
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await scrollToBottom(tester);
  });

  testWidgets('Forgot password fits a narrow phone at large text',
      (tester) async {
    await pumpSurface(
      tester,
      const ForgotPasswordPage(),
      pageIsScaffold: true,
      height: 700,
    );
    await scrollToBottom(tester);
  });

  testWidgets('Legal page fits a narrow phone at large text', (tester) async {
    await pumpSurface(
      tester,
      const LegalPage(kind: LegalKind.privacy),
      pageIsScaffold: true,
      height: 700,
    );
    await scrollToBottom(tester);
  });

  testWidgets('main navigation fits 320 px at 1.3x text', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalStore.demoSessionKey: true,
      LocalStore.profileKey: jsonEncode(adultProfile().toJson()),
    });
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(const MacroLensApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.document_scanner_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.restaurant_menu_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
