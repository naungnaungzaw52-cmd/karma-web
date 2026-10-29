// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:karma/main.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:provider/provider.dart'; // 🌟 Theme Provider အတွက် ထည့်သွင်းခြင်း
import 'package:karma/utilis/theme_provider.dart'; // 🌟 Theme Provider path

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // User ရဲ့ Username ကို Firestore ကနေ အလိုအလျောက် ဆွဲထုတ်ခြင်း
  Future<void> _fetchUserData() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          var data = userDoc.data() as Map<String, dynamic>?;
          setState(() {
            _usernameController.text = data?['username'] ??
                data?['name'] ??
                user.email ??
                'Unknown User';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Admin ထံသို့ အကူအညီတောင်းခံချက် (Support Ticket) ပို့မည့် Method
  Future<void> _submitHelpRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('support_requests').add({
        'uid': user.uid,
        'username': _usernameController.text.trim(),
        'email': user.email ?? '',
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // 🌟 Theme Provider ချိတ်ဆက်၍ Dialog background ကို Theme အလိုက်ပြောင်းရန်
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      Color dialogBgColor;
      if (themeProvider.currentTheme == 'Default') {
        dialogBgColor = Colors.white;
      } else if (themeProvider.currentTheme == 'Soft Rose' ||
          themeProvider.currentTheme == 'Sunset Glow') {
        dialogBgColor = const Color(0xFF1E1E1E).withOpacity(0.85);
      } else {
        dialogBgColor = const Color(0xFF121212).withOpacity(0.85);
      }
      Color textColor = themeProvider.getTextColor();

      // အောင်မြင်ကြောင်း Dialog ပြသခြင်း
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ValueListenableBuilder<bool>(
          valueListenable: isMyanmarNotifier,
          builder: (context, isMm, child) {
            return AlertDialog(
              backgroundColor: dialogBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isMm ? "တောင်းဆိုမှု အောင်မြင်ပါသည်" : "Request Successful",
                style: TextStyle(color: textColor),
              ),
              content: Text(
                isMm
                    ? "သင့်၏ အကူအညီတောင်းခံမှုကို Admin ထံသို့ ပို့ပြီးပါပြီ။ မကြာမီ ပြန်လည်ဆက်သွယ်ပေးပါမည်။"
                    : "Your help request has been sent to the admin. We will get back to you soon.",
                style: TextStyle(
                    color: isDarkTheme(themeProvider)
                        ? Colors.grey[300]
                        : Colors.grey[800]),
              ),
              actions: [
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.pop(context); // Dialog ပိတ်မည်
                    Navigator.pop(context); // Help Page မှ ထွက်မည်
                  },
                  child: Text(
                    isMm ? "ကောင်းပြီ" : "OK",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      final isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm ? "အမှားအယွင်း ဖြစ်ပေါ်သွားသည်: $e" : "An error occurred: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool isDarkTheme(ThemeProvider themeProvider) =>
      themeProvider.currentTheme != 'Default';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = isDarkTheme(themeProvider);
    Color textColor = themeProvider.getTextColor();

    return Container(
      decoration: themeProvider
          .getBackgroundDecoration(), // 🌟 Theme Background ထည့်သွင်းခြင်း
      child: Scaffold(
        backgroundColor: Colors
            .transparent, // 🌟 Transparent လုပ်မှ Background Gradient ပေါ်မည်
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return Text(
                isMm ? 'အကူအညီတောင်းခံရန်' : 'Help & Support',
                style: TextStyle(color: textColor, fontSize: 18),
              );
            },
          ),
          iconTheme: IconThemeData(color: textColor),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isMyanmarNotifier,
                      builder: (context, isMm, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const BannerAdWidget(),
                            const SizedBox(height: 16),
                            Text(
                              isMm
                                  ? "သင့်တွင် အခက်အခဲ သို့မဟုတ် မေးမြန်းလိုသည်များ ရှိပါက အောက်ပါဖောင်ကို ဖြည့်စွက်၍ ပို့နိုင်ပါသည်။"
                                  : "If you have any difficulties or questions, please fill out the form below and send it.",
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 1. အကောင့် Username
                            TextFormField(
                              controller: _usernameController,
                              readOnly: true,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: isMm
                                    ? 'အကောင့် Username'
                                    : 'Account Username',
                                labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700]),
                                border: const OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white30
                                          : Colors.grey),
                                ),
                                prefixIcon: Icon(Icons.person,
                                    color:
                                        isDark ? Colors.white70 : Colors.grey),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.withOpacity(0.05),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 2. အကြောင်းအရာ (Subject)
                            TextFormField(
                              controller: _subjectController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: isMm
                                    ? 'အကြောင်းအရာ (ဥပမာ - ငွေထုတ်ယူခြင်း အခက်အခဲ)'
                                    : 'Subject (e.g., Withdrawal Issue)',
                                labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700]),
                                border: const OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white30
                                          : Colors.grey),
                                ),
                                prefixIcon: Icon(Icons.subject,
                                    color:
                                        isDark ? Colors.white70 : Colors.grey),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.withOpacity(0.05),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return isMm
                                      ? 'ကျေးဇူးပြု၍ အကြောင်းအရာ ထည့်ပါ။'
                                      : 'Please enter a subject.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // 3. အသေးစိတ် ဖော်ပြချက် (Message / Description)
                            TextFormField(
                              controller: _messageController,
                              maxLines: 5,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                labelText: isMm
                                    ? 'အသေးစိတ် ဖော်ပြချက်'
                                    : 'Detailed Description',
                                labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700]),
                                alignLabelWithHint: true,
                                border: const OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white30
                                          : Colors.grey),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.withOpacity(0.05),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return isMm
                                      ? 'ကျေးဇူးပြု၍ အသေးစိတ် အချက်အလက် ထည့်ပါ။'
                                      : 'Please enter details.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // ပို့ရန် ခလုတ်
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed:
                                  _isSubmitting ? null : _submitHelpRequest,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      isMm
                                          ? 'အကူအညီ တောင်းခံမည်'
                                          : 'Submit Help Request',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
