import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  // လက်ရှိ ဘာသာစကား (ဥပမာ - 'mm' အတွက် မြန်မာ၊ 'en' အတွက် အင်္ဂလိပ်၊ 'th' အတွက် ထိုင်း)
  String _currentLanguage = 'mm';

  String get currentLanguage => _currentLanguage;
  bool get isMm => _currentLanguage == 'mm';
  bool get isEn => _currentLanguage == 'en';
  bool get isTh => _currentLanguage == 'th';

  LanguageProvider() {
    _loadLanguageFromPrefs();
  }

  // ဘာသာစကား ပြောင်းလဲသည့် လုပ်ဆောင်ချက်
  Future<void> setLanguage(String langCode) async {
    if (_currentLanguage == langCode) return;
    _currentLanguage = langCode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', langCode);
  }

  // သိမ်းဆည်းထားသော Language ကို ပြန်ဖတ်ရန်
  Future<void> _loadLanguageFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('app_language') ?? 'mm';
    notifyListeners();
  }
}
