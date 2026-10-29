import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  String _currentTheme = 'Default';

  String get currentTheme => _currentTheme;

  // Key for SharedPreferences
  static const String _themeKey = 'saved_theme';

  ThemeProvider() {
    // App စဖွင့်ချိန်မှာ SharedPreferences ထဲက သိမ်းထားတဲ့ Theme ကို ပြန်ဖတ်ပါ
    loadTheme();
  }

  Decoration getBackgroundDecoration() {
    switch (_currentTheme) {
      case 'Dark Theme':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2C3E50), // အပြာရောင်သန်းတဲ့ အနက်ရင့်
              Color(0xFF000000), // အနက်စစ်စစ်
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'Ocean Gradient':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.teal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'Midnight Velvet':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'Neon Purple':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF8A2BE2), // Violet / Neon Purple အလင်း
              Color(0xFF4B0082), // Indigo / ရင့်ရင့်လေး
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'Sunset Glow':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'Royal Sky':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'Forest Green':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'Soft Rose':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      case 'Luxury Gold':
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDC830), Color(0xFFF37335)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      default:
        return const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF), // အဖြူရောင်
              Color(0xFFF5F5F5), // အဖြူနုလေး (Off-white)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
    }
  }

  Color getTextColor() {
    switch (_currentTheme) {
      case 'Dark Theme':
      case 'Neon Purple':
      case 'Ocean Gradient':
      case 'Sunset Gradient':
      case 'Sunset Glow':
      case 'Royal Sky':
      case 'Forest Green':
      case 'Soft Rose':
      case 'Luxury Gold':
        return Colors.white;
      default:
        return Colors.black87;
    }
  }

  // Theme ပြောင်းလဲပြီး SharedPreferences ထဲမှာ သိမ်းဆည်းရန်
  Future<void> setTheme(String themeName) async {
    if (_currentTheme != themeName) {
      _currentTheme = themeName;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_themeKey, themeName);
      } catch (e) {
        debugPrint('Error saving theme: $e');
      }
    }
  }

  // Local Storage ထဲက သိမ်းထားခဲ့တဲ့ Theme ကို ပြန်လည်ဖတ်ရှုရန်
  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);

      if (savedTheme != null && _currentTheme != savedTheme) {
        _currentTheme = savedTheme;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Color getTextColorForBackground(bool isWhiteBackground) {
    return isWhiteBackground ? Colors.black87 : Colors.white;
  }
}
