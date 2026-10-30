import 'dart:convert';
import 'dart:async';
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
      this.fat100, this.aliases);
  final String name;
  final double kcal100, protein100, carbs100, fat100;
  final List<String> aliases;
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
  String sex = 'Female';
  int age = 24;
  double height = 165, weight = 60, activity = 1.375;
  double get bmr =>
      10 * weight + 6.25 * height - 5 * age + (sex == 'Male' ? 5 : -161);
  double get calories => (bmr * activity).roundToDouble();
  double get proteinGoal => calories * .30 / 4;
  double get carbsGoal => calories * .40 / 4;
  double get fatGoal => calories * .30 / 9;
}

class MacroTrackApp extends StatefulWidget {
  const MacroTrackApp({super.key});
  @override
  State<MacroTrackApp> createState() => _MacroTrackAppState();
}

class _MacroTrackAppState extends State<MacroTrackApp> {
  bool signedIn = false;
  bool sessionLoaded = false;
  int tab = 0;
  static const _demoSessionKey = 'macrolens.demo.signed_in';
  final profile = HealthProfile();
  final entries = <MealEntry>[];
  DateTime selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadDemoSession();
  }

  Future<void> _loadDemoSession() async {
    var restoredSession = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      restoredSession = preferences.getBool(_demoSessionKey) ?? false;
    } catch (_) {
      // If local storage is unavailable, fall back to the sign-in screen.
    }
    if (!mounted) return;
    setState(() {
      signedIn = restoredSession;
      sessionLoaded = true;
    });
  }

  Future<void> _continueDemo() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_demoSessionKey, true);
    if (!mounted) return;
    setState(() => signedIn = true);
  }

  Future<void> _signOut() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_demoSessionKey);
    if (!mounted) return;
    setState(() {
      signedIn = false;
      tab = 0;
    });
  }

  List<MealEntry> get todays => entries
      .where((e) =>
          e.date.year == selectedDay.year &&
          e.date.month == selectedDay.month &&
          e.date.day == selectedDay.day)
      .toList();
  double get kcal => todays.fold(0, (s, e) => s + e.kcal);
  double get protein => todays.fold(0, (s, e) => s + e.protein);
  double get carbs => todays.fold(0, (s, e) => s + e.carbs);
  double get fat => todays.fold(0, (s, e) => s + e.fat);
  void add(MealEntry e) => setState(() => entries.insert(0, e));
  void remove(MealEntry e) => setState(() => entries.remove(e));
  void changeDay(DateTime d) => setState(() => selectedDay = d);
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'MacroLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvas,
          colorScheme: ColorScheme.fromSeed(
              seedColor: green, primary: green, surface: canvas),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE6DC))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE6DC))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: green, width: 1.5)),
          ),
          fontFamily: 'Roboto'),
      home: !sessionLoaded
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator(color: green)))
          : signedIn
              ? Scaffold(
                  body: SafeArea(
                      child: IndexedStack(index: tab, children: [
                    Dashboard(
                        day: selectedDay,
                        entries: todays,
                        allEntries: entries,
                        kcal: kcal,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                        profile: profile,
                        onScan: () => setState(() => tab = 1),
                        onDate: changeDay,
                        onAdd: add,
                        onRemove: remove,
                        onShowLog: () => setState(() => tab = 2)),
                    ScannerPage(onAdd: (e) {
                      add(e);
                      changeDay(e.date);
                      setState(() => tab = 0);
                    }),
                    FoodLogPage(
                        day: selectedDay,
                        entries: todays,
                        onDate: changeDay,
                        onAdd: add,
                        onRemove: remove),
                    ProfilePage(
                        profile: profile,
                        onSaved: () => setState(() {}),
                        onSignOut: _signOut)
                  ])),
                  bottomNavigationBar: NavigationBar(
                      selectedIndex: tab,
                      onDestinationSelected: (i) => setState(() => tab = i),
                      backgroundColor: Colors.white,
                      indicatorColor: lime,
                      destinations: const [
                        NavigationDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: 'Today'),
                        NavigationDestination(
                            icon: Icon(Icons.document_scanner_outlined),
                            selectedIcon: Icon(Icons.document_scanner_rounded),
                            label: 'Scanner'),
                        NavigationDestination(
                            icon: Icon(Icons.restaurant_menu_outlined),
                            selectedIcon: Icon(Icons.restaurant_menu),
                            label: 'Food log'),
                        NavigationDestination(
                            icon: Icon(Icons.person_outline_rounded),
                            selectedIcon: Icon(Icons.person_rounded),
                            label: 'Profile')
                      ]))
              : LoginPage(onContinue: _continueDemo));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onContinue});
  final Future<void> Function() onContinue;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool accepted = false;
  bool register = false;
  bool showPassword = false;
  bool submitting = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> enterDemo() async {
    if (!accepted || !(formKey.currentState?.validate() ?? false)) return;
    password.clear();
    setState(() => submitting = true);
    try {
      await widget.onContinue();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save this device’s sign-in. Try again.')));
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                              color: green,
                              borderRadius: BorderRadius.circular(22)),
                          child: const Icon(Icons.center_focus_strong_rounded,
                              color: Colors.white, size: 36),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('MacroLens',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: ink,
                              fontSize: 27,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 7),
                      Text(register ? 'Create your account' : 'Welcome back',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: ink,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text(
                          register
                              ? 'Start building a clearer picture of your nutrition.'
                              : 'Sign in to continue tracking your nutrition.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: muted, fontSize: 13)),
                      const SizedBox(height: 25),
                      if (register) ...[
                        TextFormField(
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                              labelText: 'Your name',
                              prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 13),
                      ],
                      TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded)),
                        validator: (v) => (v ?? '').contains('@')
                            ? null
                            : 'Enter a valid email address.',
                      ),
                      const SizedBox(height: 13),
                      TextFormField(
                        controller: password,
                        obscureText: !showPassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: showPassword
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () =>
                                setState(() => showPassword = !showPassword),
                            icon: Icon(showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          ),
                        ),
                        validator: (v) => (v ?? '').length >= 6
                            ? null
                            : 'Use at least 6 characters.',
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: accepted,
                        onChanged: (v) => setState(() => accepted = v ?? false),
                        title: Wrap(children: [
                          const Text('I agree to the ',
                              style: TextStyle(fontSize: 12, color: muted)),
                          _LegalLink(
                              label: 'Terms',
                              onTap: () => showLegal(context, LegalKind.terms)),
                          const Text(' and ',
                              style: TextStyle(fontSize: 12, color: muted)),
                          _LegalLink(
                              label: 'Privacy Policy',
                              onTap: () =>
                                  showLegal(context, LegalKind.privacy)),
                        ]),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: accepted && !submitting ? enterDemo : null,
                          style: FilledButton.styleFrom(
                              backgroundColor: green,
                              foregroundColor: Colors.white),
                          child: submitting
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(
                                  register ? 'Create demo account' : 'Sign in',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 13),
                      TextButton(
                        onPressed: () => setState(() => register = !register),
                        child: Text(register
                            ? 'Already have an account? Sign in'
                            : 'New to MacroLens? Create an account'),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                            color: lime.withValues(alpha: .6),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Text(
                          'Prototype sign-in: your email and password are not sent or saved. This device remembers that you entered the demo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

enum LegalKind { terms, privacy }

void showLegal(BuildContext context, LegalKind kind) {
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => LegalPage(kind: kind)));
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Text(label,
            style: const TextStyle(
                color: green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline)),
      );
}

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.kind});
  final LegalKind kind;

  @override
  Widget build(BuildContext context) {
    final terms = kind == LegalKind.terms;
    final sections = terms ? _termsSections : _privacySections;
    return Scaffold(
      appBar: AppBar(
        title: Text(terms ? 'Terms of Service' : 'Privacy Policy'),
        backgroundColor: canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        children: [
          Text(
              terms ? 'MacroLens Terms of Service' : 'MacroLens Privacy Policy',
              style: const TextStyle(
                  color: ink, fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Prototype draft · Last updated October 30, 2026',
              style: TextStyle(color: muted, fontSize: 11)),
          const SizedBox(height: 12),
          Text(
              terms
                  ? 'These terms describe use of the MacroLens nutrition-tracking prototype. By continuing, you agree to use it for personal, informational tracking.'
                  : 'This draft explains what the current MacroLens prototype processes. It is not a statement that a production account, cloud database, or secure authentication system is connected.',
              style: const TextStyle(color: ink, height: 1.55)),
          const SizedBox(height: 14),
          ...sections.map((section) => Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.$1,
                          style: const TextStyle(
                              color: ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text(section.$2,
                          style: const TextStyle(
                              color: muted, height: 1.5, fontSize: 13)),
                    ]),
              )),
          if (!terms)
            const SelectableText(
              'Google Gemini API terms: https://ai.google.dev/gemini-api/terms',
              style: TextStyle(color: green, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

const _termsSections = <(String, String)>[
  (
    'Prototype access',
    'MacroLens currently provides a local demonstration. Sign-in and account creation on the welcome screen are visual prototype flows only. Credentials are not verified, transmitted, or stored, and no account is created.'
  ),
  (
    'Nutrition information',
    'Food recognition, portion estimates, calorie totals, and macro values are approximate and may be incomplete or wrong. The image model only suggests food labels; displayed nutrition is calculated from the sample food catalog after you confirm a match and portion.'
  ),
  (
    'Not medical advice',
    'MacroLens is for general informational tracking only. It does not diagnose, treat, or prevent any condition and is not a substitute for medical or dietetic advice. Consult a qualified professional for personal health decisions.'
  ),
  (
    'Acceptable use',
    'Use only photos you have permission to use. Do not use the prototype for emergencies, clinical decisions, or to process information about another person without their permission.'
  ),
  (
    'Availability and changes',
    'This prototype is provided for testing and may be changed or unavailable at any time. Data can be lost when the app closes or is reinstalled.'
  ),
  (
    'Contact',
    'This prototype has no connected support or account service. Before public release, replace this draft with the operator’s legal name, contact address, effective date, and locally reviewed terms.'
  ),
];

const _privacySections = <(String, String)>[
  (
    'Prototype and account data',
    'The app has no authentication backend or cloud database. Login fields are used only for local form validation; the entered email and password are not sent or saved. A simple sign-in flag is stored on this device so the demo stays signed in. Meal entries and profile settings exist in app memory and may be lost when the app closes.'
  ),
  (
    'Food photos and AI scanning',
    'When you tap Identify food with AI, the selected food photo is sent from your phone over HTTPS to the hosted MacroLens scanner. That service forwards the image and a food-identification prompt to Google Gemini API, then returns candidate food names. Do not scan people, documents, or sensitive images.'
  ),
  (
    'Google Gemini and free use',
    'If the backend uses an unpaid Gemini API quota, Google’s terms say submitted prompts, images, and responses may be used to improve Google services and may be reviewed by people. Do not submit sensitive, confidential, or personal information to unpaid Gemini services. Google handles that processing under its own terms and privacy policy.'
  ),
  (
    'Nutrition calculations',
    'The app calculates nutrition locally from its small sample catalog and the portion you confirm. It does not send meal logs to the Gemini model. Estimates are informational and can be inaccurate.'
  ),
  (
    'Retention and deletion',
    'The prototype does not intentionally store scanner photos or meal logs on a server, but Google’s handling of a submitted image depends on the Gemini service tier and its terms. Closing or reinstalling the app can clear in-memory entries. Uninstalling the app also removes the locally stored demo sign-in flag. No account deletion feature exists because accounts are not connected.'
  ),
  (
    'Network and security',
    'Online scanner traffic uses HTTPS and a separate scanner access code. The Gemini API key stays on the scanner service and must not be placed in the phone app. This prototype is not a production authentication system and has not had a security review.'
  ),
  (
    'Contact and changes',
    'No privacy contact channel is connected in this prototype. Before public release, identify the responsible operator, contact details, applicable jurisdiction, retention rules, and an effective date, and have this notice reviewed for the intended markets.'
  ),
];

class Dashboard extends StatelessWidget {
  const Dashboard(
      {super.key,
      required this.day,
      required this.entries,
      required this.allEntries,
      required this.kcal,
      required this.protein,
      required this.carbs,
      required this.fat,
      required this.profile,
      required this.onScan,
      required this.onDate,
      required this.onAdd,
      required this.onRemove,
      required this.onShowLog});
  final DateTime day;
  final List<MealEntry> entries, allEntries;
  final double kcal, protein, carbs, fat;
  final HealthProfile profile;
  final VoidCallback onScan, onShowLog;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<MealEntry> onAdd, onRemove;
  @override
  Widget build(BuildContext context) {
    final meals = ['Breakfast', 'Lunch', 'Dinner', 'Snacks'];
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 22),
        children: [
          Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: ink, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.center_focus_strong_rounded,
                    color: Colors.white)),
            const SizedBox(width: 9),
            const Text('MacroLens',
                style: TextStyle(
                    color: ink, fontSize: 19, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
                onPressed: () => pickDate(context, day, onDate),
                icon: const Icon(Icons.calendar_month_outlined, color: ink))
          ]),
          const SizedBox(height: 17),
          Text(
              day.year == DateTime.now().year &&
                      day.month == DateTime.now().month &&
                      day.day == DateTime.now().day
                  ? 'TODAY'
                  : '${day.month}/${day.day}/${day.year}',
              style: const TextStyle(
                  color: muted,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          const Text('Good morning, Alex',
              style: TextStyle(
                  color: ink, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          const Text('You’re on track. Let’s log what you eat.',
              style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 14),
          Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE1EADF))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Calories today',
                                  style: TextStyle(
                                      color: muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(kcal.toStringAsFixed(0),
                                        style: const TextStyle(
                                            color: ink,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800)),
                                    const Padding(
                                        padding:
                                            EdgeInsets.only(left: 5, bottom: 6),
                                        child: Text('kcal eaten',
                                            style: TextStyle(
                                                color: muted, fontSize: 11)))
                                  ]),
                              Text(
                                  'of ${profile.calories.toStringAsFixed(0)} kcal goal',
                                  style: const TextStyle(
                                      color: muted, fontSize: 11))
                            ]),
                      ),
                      const SizedBox(width: 12),
                      SizedBox.square(
                        dimension: 66,
                        child: Stack(alignment: Alignment.center, children: [
                          CircularProgressIndicator(
                            value: profile.calories == 0
                                ? 0
                                : (kcal / profile.calories).clamp(0.0, 1.0),
                            strokeWidth: 7,
                            backgroundColor: const Color(0xFFE8F5E9),
                            color: green,
                            strokeCap: StrokeCap.round,
                          ),
                          Text(
                              '${profile.calories == 0 ? 0 : (kcal / profile.calories * 100).round()}%',
                              style: const TextStyle(
                                  color: ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800))
                        ]),
                      )
                    ]),
                    const SizedBox(height: 15),
                    Row(children: [
                      _Macro('Protein', protein, profile.proteinGoal, 'g',
                          const Color(0xFF1B5E20)),
                      _Macro('Carbs', carbs, profile.carbsGoal, 'g',
                          const Color(0xFF2E7D32)),
                      _Macro('Fat', fat, profile.fatGoal, 'g',
                          const Color(0xFF00695C))
                    ])
                  ])),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(
                child: Text('This week',
                    style: TextStyle(
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800))),
            TextButton(onPressed: onShowLog, child: const Text('History'))
          ]),
          _WeekChart(entries: allEntries, goal: profile.calories),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(
                child: Text('Meals',
                    style: TextStyle(
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800))),
            TextButton(
                onPressed: () => manualAdd(context, onAdd),
                child: const Text('+ Add food'))
          ]),
          ...meals.map((m) {
            final group = entries.where((e) => e.category == m).toList();
            final groupKcal = group.fold(0.0, (s, e) => s + e.kcal);
            return _MealGroup(
                name: m, items: group, kcal: groupKcal, onRemove: onRemove);
          }),
          const SizedBox(height: 9),
          SizedBox(
              height: 52,
              child: FilledButton.icon(
                  onPressed: onScan,
                  style: FilledButton.styleFrom(
                      backgroundColor: green, foregroundColor: Colors.white),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan food',
                      style: TextStyle(fontWeight: FontWeight.w800))))
        ]);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.goal, required this.color});
  final double value, goal;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
          value: goal == 0 ? 0 : (value / goal).clamp(0, 1),
          minHeight: 7,
          backgroundColor: const Color(0xFFDDE6DC),
          color: color));
}

class _Macro extends StatelessWidget {
  const _Macro(this.name, this.value, this.goal, this.unit, this.color);
  final String name, unit;
  final double value, goal;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
      child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(color: muted, fontSize: 10)),
            const SizedBox(height: 3),
            Text(
                '${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)}$unit',
                style: const TextStyle(
                    color: ink, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _Bar(value: value, goal: goal, color: color)
          ])));
}

class _MealGroup extends StatelessWidget {
  const _MealGroup(
      {required this.name,
      required this.items,
      required this.kcal,
      required this.onRemove});
  final String name;
  final List<MealEntry> items;
  final double kcal;
  final ValueChanged<MealEntry> onRemove;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
          padding: const EdgeInsets.fromLTRB(13, 10, 9, 7),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          color: ink, fontWeight: FontWeight.w800))),
              Text('${kcal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(color: muted, fontSize: 11))
            ]),
            if (items.isEmpty)
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 7),
                      child: Text('No food logged',
                          style: TextStyle(color: muted, fontSize: 11))))
            else
              ...items
                  .map((e) => _FoodRow(entry: e, onRemove: () => onRemove(e)))
          ])));
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.entry, this.onRemove});
  final MealEntry entry;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(entry.food.name,
          style: const TextStyle(
              color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
          '${entry.grams.toStringAsFixed(0)} g · P ${entry.protein.toStringAsFixed(1)} / C ${entry.carbs.toStringAsFixed(1)} / F ${entry.fat.toStringAsFixed(1)} g',
          style: const TextStyle(color: muted, fontSize: 10)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${entry.kcal.toStringAsFixed(0)}',
            style: const TextStyle(
                color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
        if (onRemove != null)
          IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 17, color: muted))
      ]));
}

class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.entries, required this.goal});
  final List<MealEntry> entries;
  final double goal;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(
        7, (i) => DateTime(today.year, today.month, today.day - 6 + i));
    final totals = days
        .map((day) => entries
            .where((e) =>
                e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day)
            .fold(0.0, (sum, e) => sum + e.kcal))
        .toList();
    return Container(
      height: 110,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final height =
              goal == 0 ? 0.0 : (totals[i] / goal).clamp(0.0, 1.0) * 58;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                  width: 21,
                  height: height < 3 ? 3 : height,
                  decoration: BoxDecoration(
                      color: i == 6 ? green : const Color(0xFFDCEBDD),
                      borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 5),
              Text(
                  const [
                    'M',
                    'T',
                    'W',
                    'T',
                    'F',
                    'S',
                    'S'
                  ][days[i].weekday - 1],
                  style: const TextStyle(fontSize: 9, color: muted)),
            ],
          );
        }),
      ),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.onAdd});
  final ValueChanged<MealEntry> onAdd;
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final picker = ImagePicker();
  final grams = TextEditingController(text: '150');
  XFile? photo;
  bool busy = false;
  String? error, detected;
  double confidence = 0;
  Food? selectedFood;
  String meal = 'Lunch', unit = 'g';
  @override
  void dispose() {
    grams.dispose();
    super.dispose();
  }

  Future<void> pick(ImageSource source) async {
    try {
      final file = await picker.pickImage(
          source: source, imageQuality: 84, maxWidth: 1600);
      if (file != null) {
        setState(() {
          photo = file;
          error = null;
          detected = null;
          selectedFood = null;
        });
      }
    } catch (e) {
      setState(() => error = 'Could not open image source: $e');
    }
  }

  Future<void> analyze() async {
    if (photo == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final endpoint = Uri.tryParse(scanUrl.trim());
      if (endpoint == null || !endpoint.hasScheme || endpoint.host.isEmpty) {
        throw const FormatException('Enter a valid scanner service URL.');
      }
      final mime = imageMimeType(photo!);
      if (mime == null) {
        throw const FormatException(
            'This image format is not supported. Choose a JPEG, PNG, WebP, HEIC, or HEIF photo.');
      }
      final req = http.MultipartRequest('POST', endpoint);
      final accessCode = scannerAccessCode.trim();
      if (accessCode.isNotEmpty) {
        req.headers['x-scanner-token'] = accessCode;
      }
      req.files.add(http.MultipartFile.fromBytes(
          'image', await photo!.readAsBytes(),
          filename: photo!.name, contentType: MediaType.parse(mime)));
      final response = await req
          .send()
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 150));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String detail = 'Scanner service returned ${response.statusCode}.';
        try {
          final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
          detail = (errorBody['detail'] as String?) ?? detail;
        } catch (_) {}
        if (detail.contains('Gemini analysis failed: APITimeoutError')) {
          detail =
              'Gemini took too long to analyze this photo. Please try again in a moment, or add the food manually.';
        }
        throw Exception(detail);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final first = (body['items'] as List).first as Map<String, dynamic>;
      final label = first['food_name'] as String;
      final found = matchFood(label);
      setState(() {
        detected = label;
        confidence = ((first['confidence'] as num?)?.toDouble() ?? .65);
        selectedFood = found;
      });
    } on TimeoutException {
      setState(() => error =
          'Food analysis took too long. Please try again in a moment, or add the food manually.');
    } on http.ClientException {
      setState(() => error =
          'Cannot reach the scanner service. Check your internet connection and try again.');
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void addFood() {
    final amount = double.tryParse(grams.text.trim().replaceAll(',', '.'));
    if (selectedFood == null) {
      setState(() => error = 'Select the matching food from the database.');
      return;
    }
    if (amount == null || amount <= 0 || amount > 5000) {
      setState(() => error = 'Enter a valid amount from 1 to 5,000 grams.');
      return;
    }
    final g = unit == 'oz' ? amount * 28.3495 : amount;
    widget.onAdd(MealEntry(food: selectedFood!, grams: g, category: meal));
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
        const Text('Log your meal',
            style: TextStyle(
                color: ink, fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Take a photo and let AI estimate your macros.',
            style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 18),
        Container(
            height: 245,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: const Color(0xFFEEF5ED),
                borderRadius: BorderRadius.circular(23)),
            child: photo == null
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.camera_alt_rounded, size: 48, color: green),
                    SizedBox(height: 10),
                    Text('Take a photo or upload food',
                        style:
                            TextStyle(color: ink, fontWeight: FontWeight.w700))
                  ]))
                : FutureBuilder(
                    future: photo!.readAsBytes(),
                    builder: (context, s) => s.hasData
                        ? Image.memory(s.data!,
                            fit: BoxFit.cover, width: double.infinity)
                        : const Center(
                            child: CircularProgressIndicator(color: green)))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'))),
          const SizedBox(width: 9),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload photo')))
        ]),
        const SizedBox(height: 10),
        SizedBox(
            height: 48,
            child: FilledButton(
                onPressed: photo == null || busy ? null : analyze,
                style: FilledButton.styleFrom(
                    backgroundColor: green, foregroundColor: Colors.white),
                child: busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Identify food with AI',
                        style: TextStyle(fontWeight: FontWeight.w800)))),
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12))),
        if (detected != null) ...[
          const SizedBox(height: 16),
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(17)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Confirm your food',
                        style:
                            TextStyle(color: ink, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                        'AI match: $detected (${(confidence * 100).toStringAsFixed(0)}% confidence). Nutrition uses the selected database entry.',
                        style: const TextStyle(color: muted, fontSize: 11)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<Food>(
                        initialValue: selectedFood,
                        decoration: const InputDecoration(
                            labelText: 'Food database match',
                            border: OutlineInputBorder()),
                        items: catalog
                            .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f.name,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (f) => setState(() => selectedFood = f)),
                    const SizedBox(height: 9),
                    Row(children: [
                      Expanded(
                        child: TextField(
                            controller: grams,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Portion amount',
                                border: OutlineInputBorder())),
                      ),
                      const SizedBox(width: 9),
                      SizedBox(
                          width: 88,
                          child: DropdownButtonFormField<String>(
                              initialValue: unit,
                              decoration: const InputDecoration(
                                  labelText: 'Unit',
                                  border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(
                                    value: 'g', child: Text('grams')),
                                DropdownMenuItem(
                                    value: 'oz', child: Text('ounces'))
                              ],
                              onChanged: (v) =>
                                  setState(() => unit = v ?? 'g')))
                    ]),
                    const SizedBox(height: 9),
                    DropdownButtonFormField<String>(
                        initialValue: meal,
                        decoration: const InputDecoration(
                            labelText: 'Meal', border: OutlineInputBorder()),
                        items: const ['Breakfast', 'Lunch', 'Dinner', 'Snacks']
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setState(() => meal = v ?? 'Lunch')),
                    if (selectedFood != null &&
                        double.tryParse(grams.text) != null) ...[
                      const SizedBox(height: 9),
                      _NutritionPreview(
                          food: selectedFood!,
                          grams: (double.tryParse(grams.text) ?? 0) *
                              (unit == 'oz' ? 28.3495 : 1))
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: addFood,
                            style: FilledButton.styleFrom(
                                backgroundColor: green,
                                foregroundColor: Colors.white),
                            child: const Text('Add to meal',
                                style: TextStyle(fontWeight: FontWeight.w800))))
                  ]))
        ],
        const SizedBox(height: 10),
        const Text(
            'Image analysis is approximate. Confirm food and serving size; macro totals are calculated from the local food database.',
            style: TextStyle(color: muted, fontSize: 10))
      ]);
}

class _NutritionPreview extends StatelessWidget {
  const _NutritionPreview({required this.food, required this.grams});
  final Food food;
  final double grams;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: lime.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(12)),
      child: Text(
          '${(food.kcal100 * grams / 100).round()} kcal  ·  Protein ${(food.protein100 * grams / 100).toStringAsFixed(1)}g  ·  Carbs ${(food.carbs100 * grams / 100).toStringAsFixed(1)}g  ·  Fat ${(food.fat100 * grams / 100).toStringAsFixed(1)}g',
          style: const TextStyle(
              color: ink, fontSize: 11, fontWeight: FontWeight.w700)));
}

class FoodLogPage extends StatelessWidget {
  const FoodLogPage(
      {super.key,
      required this.day,
      required this.entries,
      required this.onDate,
      required this.onAdd,
      required this.onRemove});
  final DateTime day;
  final List<MealEntry> entries;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<MealEntry> onAdd, onRemove;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          const Expanded(
              child: Text('Food history',
                  style: TextStyle(
                      color: ink, fontSize: 25, fontWeight: FontWeight.w800))),
          IconButton(
              onPressed: () => pickDate(context, day, onDate),
              icon: const Icon(Icons.calendar_month, color: ink))
        ]),
        Text('${day.month}/${day.day}/${day.year}',
            style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const Padding(
              padding: EdgeInsets.all(30),
              child: Text('No food logged for this date.',
                  textAlign: TextAlign.center, style: TextStyle(color: muted)))
        else
          ...entries
              .map((e) => _FoodRow(entry: e, onRemove: () => onRemove(e))),
        OutlinedButton.icon(
            onPressed: () => manualAdd(context, onAdd),
            icon: const Icon(Icons.add),
            label: const Text('Add food manually'))
      ]);
}

class ProfilePage extends StatelessWidget {
  const ProfilePage(
      {super.key,
      required this.profile,
      required this.onSaved,
      required this.onSignOut});
  final HealthProfile profile;
  final VoidCallback onSaved;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Profile & goals',
            style: TextStyle(
                color: ink, fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Set your details to estimate a daily calorie goal.',
            style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 16),
        Card(
            color: Colors.white,
            elevation: 0,
            child: ListTile(
                leading: const Icon(Icons.person_outline, color: green),
                title: Text('${profile.age} years · ${profile.sex}',
                    style: const TextStyle(
                        color: ink, fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${profile.height.toStringAsFixed(0)} cm · ${profile.weight.toStringAsFixed(1)} kg'),
                trailing: const Icon(Icons.edit_outlined, color: muted),
                onTap: () => editProfile(context, profile, onSaved))),
        const SizedBox(height: 10),
        Card(
            color: ink,
            child: ListTile(
                title: const Text('Estimated daily calories',
                    style: TextStyle(color: Colors.white)),
                subtitle: Text(
                    '${profile.calories.toStringAsFixed(0)} kcal · Mifflin-St Jeor × activity',
                    style: const TextStyle(color: lime)),
                leading: const Icon(Icons.bolt, color: lime))),
        const SizedBox(height: 18),
        const Text('Daily macro targets',
            style: TextStyle(
                color: ink, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        Text(
            'Protein ${profile.proteinGoal.toStringAsFixed(0)} g · Carbohydrates ${profile.carbsGoal.toStringAsFixed(0)} g · Fat ${profile.fatGoal.toStringAsFixed(0)} g',
            style: const TextStyle(color: muted)),
        const SizedBox(height: 18),
        const Text('About MacroLens',
            style: TextStyle(
                color: ink, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        Card(
          color: Colors.white,
          elevation: 0,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.description_outlined, color: green),
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: () => showLegal(context, LegalKind.terms),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: green),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: () => showLegal(context, LegalKind.privacy),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out of this device')),
        const SizedBox(height: 12),
        const Text(
            'Targets are estimates for general tracking, not medical advice.',
            style: TextStyle(color: muted, fontSize: 11))
      ]);
}

Future<void> pickDate(BuildContext context, DateTime current,
    ValueChanged<DateTime> onSelect) async {
  final d = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now());
  if (d != null) onSelect(d);
}

Future<void> manualAdd(
    BuildContext context, ValueChanged<MealEntry> onAdd) async {
  Food? food;
  String meal = 'Snacks', unit = 'g';
  final amount = TextEditingController(text: '100');
  final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
                  title: const Text('Add food'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<Food>(
                        initialValue: food,
                        decoration: const InputDecoration(labelText: 'Food'),
                        items: catalog
                            .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f.name,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => refresh(() => food = v)),
                    TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount')),
                    DropdownButtonFormField<String>(
                        initialValue: unit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: const [
                          DropdownMenuItem(value: 'g', child: Text('grams')),
                          DropdownMenuItem(value: 'oz', child: Text('ounces'))
                        ],
                        onChanged: (v) => refresh(() => unit = v ?? 'g')),
                    DropdownButtonFormField<String>(
                        initialValue: meal,
                        decoration: const InputDecoration(labelText: 'Meal'),
                        items: const ['Breakfast', 'Lunch', 'Dinner', 'Snacks']
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => refresh(() => meal = v ?? 'Snacks'))
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Add'))
                  ])));
  final g =
      (double.tryParse(amount.text.trim()) ?? 0) * (unit == 'oz' ? 28.3495 : 1);
  if (result == true && food != null && g > 0 && g <= 5000)
    onAdd(MealEntry(food: food!, grams: g, category: meal));
}

Future<void> editProfile(
    BuildContext context, HealthProfile p, VoidCallback onSaved) async {
  final age = TextEditingController(text: '${p.age}'),
      height = TextEditingController(text: '${p.height}'),
      weight = TextEditingController(text: '${p.weight}');
  String sex = p.sex;
  double activity = p.activity;
  final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
                  title: const Text('Personal nutrition profile'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<String>(
                        initialValue: sex,
                        decoration: const InputDecoration(
                            labelText: 'Sex for BMR formula'),
                        items: const ['Female', 'Male']
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => refresh(() => sex = v ?? sex)),
                    TextField(
                        controller: age,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Age (years)')),
                    TextField(
                        controller: height,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Height (cm)')),
                    TextField(
                        controller: weight,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Weight (kg)')),
                    DropdownButtonFormField<double>(
                        initialValue: activity,
                        decoration:
                            const InputDecoration(labelText: 'Activity level'),
                        items: {
                          1.2: 'Sedentary',
                          1.375: 'Light',
                          1.55: 'Moderate',
                          1.725: 'High'
                        }
                            .entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) =>
                            refresh(() => activity = v ?? activity))
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Save'))
                  ])));
  if (ok == true) {
    final a = int.tryParse(age.text),
        h = double.tryParse(height.text),
        w = double.tryParse(weight.text);
    if (a != null &&
        a >= 13 &&
        a <= 110 &&
        h != null &&
        h >= 100 &&
        h <= 250 &&
        w != null &&
        w >= 30 &&
        w <= 350) {
      p.sex = sex;
      p.age = a;
      p.height = h;
      p.weight = w;
      p.activity = activity;
      onSaved();
    }
  }
}
