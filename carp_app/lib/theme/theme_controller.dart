import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light/dark choice. Follows the device until the user picks one,
/// then remembers that choice (shared_preferences = localStorage on web).
class ThemeController extends ChangeNotifier {
  ThemeController([this.mode = ThemeMode.system]);

  static const _key = 'carp.darkMode';

  ThemeMode mode;

  /// Reads the saved choice. Nothing saved yet = follow the device.
  static Future<ThemeController> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dark = prefs.getBool(_key);
      return ThemeController(dark == null ? ThemeMode.system : (dark ? ThemeMode.dark : ThemeMode.light));
    } catch (_) {
      return ThemeController(); // storage not available: just follow the device
    }
  }

  /// Is dark mode showing right now? (Needs context for the "system" case.)
  static bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  /// Switches to dark or light right away and saves the choice.
  Future<void> setDark(bool dark) async {
    mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, dark);
    } catch (_) {
      // Saving failed (e.g. private window). The switch still works for now.
    }
  }
}
