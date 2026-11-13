import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/food_log_page.dart';
import 'screens/login_page.dart';
import 'screens/profile_page.dart';
import 'screens/scanner_page.dart';
import 'screens/today_page.dart';
import 'storage.dart';
import 'theme.dart';
import 'ui/common.dart';

void main() => runApp(const MacroLensApp());

class MacroLensApp extends StatefulWidget {
  const MacroLensApp({super.key});

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
      'Added ${entry.food.name}',
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

  void _showSnack(String message, {SnackBarAction? action}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
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
