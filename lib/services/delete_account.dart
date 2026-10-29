// ignore_for_file: use_build_context_synchronously

// ignore: unnecessary_import
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:karma/main.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // 🔗 Google Form ဖြင့် အကောင့်ဖျက်ရန် Request တင်မည့် Public Form Link
  final String webDeleteFormUrl =
      'https://docs.google.com/forms/d/e/1FAIpQLScVb6wyZhQPh4cVmkAN1SQZR6vg-hq01xIaM2sOy3SknOC8mQ/viewform?usp=header';

  Future<void> _launchWebForm(BuildContext context) async {
    final Uri url = Uri.parse(webDeleteFormUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Link ကို ဖွင့်၍မရပါ။")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // 🌟 User Data, Posts နှင့် FirebaseAuth အကောင့်ပါ အစအဆုံး ဖျက်ပေးမည့် Function
  Future<void> _deleteUserAccountCompletely(BuildContext context) async {
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      String uid = user!.uid;

      // ၁။ User တင်ထားခဲ့သော Post များကို Firestore (posts collection) မှ လိုက်လံဖျက်မည်
      var postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .get();

      for (var doc in postsQuery.docs) {
        await doc.reference.delete();
      }

      // ၂။ Firestore ထဲမှ သက်ဆိုင်ရာ User Document ကို ဖျက်မည်
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // ၃။ FirebaseAuth ထဲမှ အကောင့်ကို ဖျက်မည်
      await user!.delete();

      // Loading ပိတ်မည်
      Navigator.of(context, rootNavigator: true).pop();

      final isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? "အကောင့်နှင့် တင်ထားသော Post များ အားလုံး အပြီးတိုင် ဖျက်သိမ်းပြီးပါပြီ။\n(Account and all posts permanently deleted.)"
                : "Account and all posts permanently deleted.\n(အကောင့်နှင့် တင်ထားသော Post များ အားလုံး အပြီးတိုင် ဖျက်သိမ်းပြီးပါပြီ။)",
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Main/Login စာမျက်နှာသို့ ပြန်ညွှန်းမည်
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      Navigator.of(context, rootNavigator: true).pop();

      final isMm = isMyanmarNotifier.value;
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? "လုံခြုံရေးအရ အကောင့်ထွက်ပြီး ပြန်ဝင်ကာမှ အကောင့်ဖျက်ပေးပါရန်။\n(Please log out and log back in for security reasons before deleting.)"
                  : "Please log out and log back in for security reasons before deleting.\n(လုံခြုံရေးအရ အကောင့်ထွက်ပြီး ပြန်ဝင်ကာမှ အကောင့်ဖျက်ပေးပါရန်။)",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? "အကောင့်ဖျက်ရာတွင် အမှားဖြစ်ပွားပါသည်: ${e.message}\n(Error deleting account: ${e.message})"
                  : "Error deleting account: ${e.message}\n(အကောင့်ဖျက်ရာတွင် အမှားဖြစ်ပွားပါသည်: ${e.message})",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🌟 အတည်ပြုချက် Confirmation Dialog
  void _showDeleteConfirmDialog(BuildContext context, bool isMm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isMm ? "အကောင့်ဖျက်ရန် အတည်ပြုပါ" : "Confirm Account Deletion",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isMm
              ? "သင့်အကောင့်၊ ကိုယ်ရေးအချက်အလက်များနှင့် သင်တင်ထားသော Post များအားလုံး အပြီးတိုင် ပျက်စီးသွားမည် ဖြစ်ပါသည်။ ဆက်လက် လုပ်ဆောင်လိုပါသလား။"
              : "Are you sure? All your profile info, data, and posts will be permanently deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isMm ? "မလုပ်တော့ပါ" : "Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUserAccountCompletely(context);
            },
            child: Text(
              isMm ? "ဖျက်မည်" : "Delete",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDarkMode = (themeProvider.currentTheme != 'Default');
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return Text(
                isMm ? "အကောင့်ဖျက်သိမ်းခြင်း" : "Delete Account",
                style: TextStyle(color: textColor),
              );
            },
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        size: 70,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 25),
                    ValueListenableBuilder<bool>(
                      valueListenable: isMyanmarNotifier,
                      builder: (context, isMm, child) {
                        return Column(
                          children: [
                            Text(
                              isMm
                                  ? "အကောင့်နှင့် ဒေတာများ အပြီးတိုင်ဖျက်ရန်"
                                  : "Permanently Delete Account & Data",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isMm
                                  ? "အကောင့်ဖျက်လိုက်ပါက သင့်အကောင့်၊ ကိုယ်ရေးအချက်အလက်များနှင့် သင်တင်ထားခဲ့သော Post များနှင့် Data အားလုံး လုံးဝ ပျက်စီးသွားမည် ဖြစ်ပါသည်။ အောက်ပါ နည်းလမ်းများဖြင့် ဖျက်နိုင်ပါသည် -"
                                  : "Deleting your account will permanently remove your profile, data, and all your posts. You can delete via the options below:",
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor.withOpacity(0.7),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 30),

                    // 🚀 1. App ထဲကနေ တိုက်ရိုက်ဖျက်မည့် ခလုတ်
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showDeleteConfirmDialog(
                            context, isMyanmarNotifier.value),
                        icon: const Icon(Icons.delete_forever),
                        label: ValueListenableBuilder<bool>(
                          valueListenable: isMyanmarNotifier,
                          builder: (context, isMm, child) {
                            return Text(
                              isMm
                                  ? "ဤ App ထဲမှ အကောင့်နှင့် Data များဖျက်မည်"
                                  : "Delete Account & Data from App",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🌐 2. Web / Google Form ကနေတဆင့် ဖျက်ရန် Request တင်မည့် ခလုတ်
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: textColor.withOpacity(0.3)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _launchWebForm(context),
                        icon: const Icon(Icons.web, color: Colors.blueAccent),
                        label: ValueListenableBuilder<bool>(
                          valueListenable: isMyanmarNotifier,
                          builder: (context, isMm, child) {
                            return Text(
                              isMm
                                  ? "Website (Google Form) မှတဆင့် ဖျက်ရန်"
                                  : "Request Deletion via Web Form",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}
