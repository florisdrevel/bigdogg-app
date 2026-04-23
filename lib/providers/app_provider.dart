import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  String _language = 'en';
  bool _projectsEnabled = false;
  bool _hasSeenWalkthrough = true; // default true — only false once prefs confirm it
  bool _prefsLoaded = false;

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get projectsEnabled => _projectsEnabled;
  bool get hasSeenWalkthrough => _hasSeenWalkthrough;
  bool get prefsLoaded => _prefsLoaded;

  AppProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'light';
    final lang = prefs.getString('language') ?? 'en';
    final projects = prefs.getBool('projects_enabled') ?? false;
    final seen = prefs.getBool('has_seen_walkthrough') ?? false;
    _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _language = lang;
    _projectsEnabled = projects;
    _hasSeenWalkthrough = seen;
    _prefsLoaded = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', _themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  Future<void> setProjectsEnabled(bool enabled) async {
    _projectsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('projects_enabled', enabled);
    notifyListeners();
  }

  Future<void> markWalkthroughSeen() async {
    _hasSeenWalkthrough = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_walkthrough', true);
    notifyListeners();
  }

  Future<void> resetWalkthrough() async {
    _hasSeenWalkthrough = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_walkthrough', false);
    notifyListeners();
  }
}