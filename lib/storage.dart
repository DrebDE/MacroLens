import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Everything the app restores from local storage at launch.
class LocalData {
  const LocalData({
    required this.signedIn,
    required this.profile,
    required this.entries,
  });

  final bool signedIn;
  final HealthProfile profile;
  final List<MealEntry> entries;
}

/// Device-only storage for the demo session, profile, and meal history.
///
/// This is not an account service. Email and password are never persisted.
class LocalStore {
  static const demoSessionKey = 'macrolens.demo.signed_in';
  static const profileKey = 'macrolens.profile.v1';
  static const logKey = 'macrolens.log.v1';

  static const _maxStoredEntries = 2000;

  Future<void> _writeQueue = Future<void>.value();

  Future<LocalData> load() async {
    final profile = HealthProfile();
    var signedIn = false;
    final entries = <MealEntry>[];
    try {
      final preferences = await SharedPreferences.getInstance();
      signedIn = preferences.getBool(demoSessionKey) ?? false;

      final savedProfile = preferences.getString(profileKey);
      if (savedProfile != null) {
        try {
          final decoded = jsonDecode(savedProfile);
          if (decoded is Map<String, dynamic>) profile.restore(decoded);
        } catch (_) {
          // Ignore a corrupt profile and show setup again.
        }
      }

      final savedLog = preferences.getString(logKey);
      if (savedLog != null) {
        try {
          final decoded = jsonDecode(savedLog);
          if (decoded is List) {
            for (final item in decoded.take(_maxStoredEntries)) {
              final entry = MealEntry.fromJson(item);
              if (entry != null) entries.add(entry);
            }
          }
        } catch (_) {
          // Ignore a corrupt log rather than blocking the app.
        }
      }
    } catch (_) {
      // Local storage is unavailable. The app can still run for this session.
    }
    return LocalData(signedIn: signedIn, profile: profile, entries: entries);
  }

  Future<void> saveSignedIn(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    if (value) {
      await preferences.setBool(demoSessionKey, true);
    } else {
      await preferences.remove(demoSessionKey);
    }
  }

  Future<void> saveProfile(HealthProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(profileKey, jsonEncode(profile.toJson()));
  }

  /// Writes are serialized so quick add/remove actions cannot reorder.
  Future<void> saveLog(List<MealEntry> entries) {
    final encoded = jsonEncode(
      entries.take(_maxStoredEntries).map((entry) => entry.toJson()).toList(),
    );
    final next = _writeQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(logKey, encoded);
    });
    _writeQueue = next.catchError((_) {});
    return next;
  }

  Future<void> clearLog() {
    final next = _writeQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(logKey);
    });
    _writeQueue = next.catchError((_) {});
    return next;
  }
}
