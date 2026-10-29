// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  // Cloudflare Worker ရဲ့ URL (ဖိုင်တင်တဲ့နေရာမှာ သုံးတဲ့ Worker URL ပါပဲ)
  static const String _workerUrl =
      "https://karma-api777.naungnaungzaw52.workers.dev";

  static Future<void> sendNotification(
      String token, String message, String title, String type,
      {String? callId,
      String? callerName,
      String? senderId,
      String? callerAvatar}) async {
    try {
      // Secret များကို App ထဲတွင် မသိမ်းတော့ဘဲ Cloudflare Worker သို့ တာဝန်လွှဲပြောင်းပေးခြင်း
      final response = await http.post(
        Uri.parse('$_workerUrl/send-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'title': title,
          'message': message,
          'type': type,
          'callId': callId ?? '',
          'callerName': callerName ?? 'အမည်မသိ',
          'senderId': senderId ?? '',
          'callerAvatar': callerAvatar ?? '', // နိုင်ငံတကာ CallKit အတွက်
          'senderAvatar': callerAvatar ??
              '', // Worker ဘက်က လိုအပ်တဲ့ Key အတွက်ပါ ထပ်ထည့်ခြင်း
        }),
      );

      if (response.statusCode == 200) {
        print("Notification Sent Successfully via Worker");
      } else {
        print("Notification Failed: ${response.body}");
      }
    } catch (e) {
      print("Notification Error: $e");
    }
  }
}
