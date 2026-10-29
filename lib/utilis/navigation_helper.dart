import 'package:flutter/material.dart';

class NavigationHelper {
  // Navigator.push အတွက်
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  // Navigator.pushReplacement အတွက်
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget page) {
    return Navigator.pushReplacement<T, TO>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  // Navigator.pushAndRemoveUntil အတွက်
  static Future<T?> pushAndRemoveUntil<T>(BuildContext context, Widget page,
      {bool keepHistory = false}) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      MaterialPageRoute(builder: (context) => page),
      (Route<dynamic> route) => keepHistory,
    );
  }

  // Pop (နောက်သို့ပြန်ရန်)
  static void pop(BuildContext context, [dynamic result]) {
    Navigator.pop(context, result);
  }
}
