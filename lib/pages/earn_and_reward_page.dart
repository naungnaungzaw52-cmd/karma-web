// ignore_for_file: use_build_context_synchronously

import 'dart:ui'; // 🌟 BackdropFilter အတွက် လိုအပ်သည်
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:karma/pages/payment_request_page.dart';
import 'package:karma/pages/income_analysis_page.dart';
import 'package:karma/pages/withdraw_history_page.dart';
import 'package:karma/pages/deposit_request_page.dart';

class EarnAndRewardPage extends StatefulWidget {
  const EarnAndRewardPage({super.key});

  @override
  State<EarnAndRewardPage> createState() => _EarnAndRewardPageState();
}

class _EarnAndRewardPageState extends State<EarnAndRewardPage> {
  bool _isVerified = false; // Password အမှန်ထည့်ပြီးမှ Page ကို မြင်ရစေရန်
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPasswordRequirement();
  }

  // 🌟 Database ထဲတွင် Password ရှိမရှိ စစ်ဆေးပြီး Dialog ပြသခြင်း
  Future<void> _checkPasswordRequirement() async {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    setState(() {
      _isVerified = false;
      _isLoading = true;
    });

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();

      if (!mounted) return;

      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        String? savedPassword = data?['rewardPassword'];

        if (savedPassword == null || savedPassword.isEmpty) {
          // Password မရှိသေးပါက အသစ်သတ်မှတ်ခိုင်းမည်
          _showCreatePasswordDialog(currentUid);
        } else {
          // Password ရှိပြီးသားဆိုပါက ရိုက်ထည့်ရန် တောင်းမည်
          _showEnterPasswordDialog(savedPassword);
        }
      } else {
        setState(() {
          _isLoading = false;
          _isVerified = true;
        });
      }
    } catch (e) {
      // Error ဖြစ်ပါက ကျော်ရန် သို့မဟုတ် Handle လုပ်ရန်
      setState(() {
        _isLoading = false;
        _isVerified = true;
      });
    }
  }

  // 1️⃣ Password အသစ် သတ်မှတ်ခိုင်းမည့် Dialog
  void _showCreatePasswordDialog(String uid) {
    final TextEditingController passwordController = TextEditingController();

    // 🌟 Theme နှင့် စာသားအရောင် သတ်မှတ်ခြင်း
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool isDarkMode = (themeProvider.currentTheme != 'Default');
    Color dialogTextColor = isDarkMode ? Colors.white : Colors.black87;

    Color dialogBgColor;
    if (themeProvider.currentTheme == 'Default') {
      dialogBgColor = Colors.white.withOpacity(0.85);
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      dialogBgColor = Colors.white.withOpacity(0.15);
    } else {
      dialogBgColor = Colors.black.withOpacity(0.6);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBgColor,
        title: Text("လုံခြုံရေးအတွက် Password သတ်မှတ်ပါ",
            style: TextStyle(color: dialogTextColor)), // 🌟 Title အရောင်
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Earn & Reward စနစ်ကို ဝင်ရောက်ရန်နှင့် ငွေထုတ်ယူရန် PIN (သို့မဟုတ်) Password အသစ်တစ်ခု သတ်မှတ်ပါ။",
              style:
                  TextStyle(color: dialogTextColor), // 🌟 Content Text အရောင်
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: TextStyle(
                  color: dialogTextColor), // 🌟 Input typing text အရောင်
              decoration: InputDecoration(
                labelText: "Password အသစ် (ဂဏန်း ၆ လုံး)",
                labelStyle: TextStyle(
                    color: dialogTextColor.withOpacity(0.7)), // 🌟 Label အရောင်
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: dialogTextColor.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: dialogTextColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.trim().length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          "ကျေးဇူးပြု၍ Password အနည်းဆုံး ၄ လုံး ထည့်ပါ။")),
                );
                return;
              }

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({
                'rewardPassword': passwordController.text.trim(),
              });

              Navigator.pop(context);
              setState(() {
                _isVerified = true;
                _isLoading = false;
              });
            },
            child: const Text("သိမ်းမည်"),
          ),
        ],
      ),
    );
  }

  // 2️⃣ ရှိပြီးသား Password ကို တောင်းခံမည့် Dialog
  void _showEnterPasswordDialog(String savedPassword) {
    final TextEditingController passwordController = TextEditingController();

    // 🌟 Theme နှင့် စာသားအရောင် သတ်မှတ်ခြင်း
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool isDarkMode = (themeProvider.currentTheme != 'Default');
    Color dialogTextColor = isDarkMode ? Colors.white : Colors.black87;

    Color dialogBgColor;
    if (themeProvider.currentTheme == 'Default') {
      dialogBgColor = Colors.white.withOpacity(0.85);
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      dialogBgColor = Colors.white.withOpacity(0.15);
    } else {
      dialogBgColor = Colors.black.withOpacity(0.6);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      // ignore: deprecated_member_use
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: dialogBgColor,
          title: Text("လုံခြုံရေး စစ်ဆေးခြင်း",
              style: TextStyle(color: dialogTextColor)), // 🌟 Title အရောင်
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Earn & Reward စနစ်သို့ ဝင်ရောက်ရန် သင့် Password ကို ရိုက်ထည့်ပါ။",
                style:
                    TextStyle(color: dialogTextColor), // 🌟 Content Text အရောင်
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: TextStyle(
                    color: dialogTextColor), // 🌟 Input typing text အရောင်
                decoration: InputDecoration(
                  labelText: "Password ထည့်ရန်",
                  labelStyle: TextStyle(
                      color:
                          dialogTextColor.withOpacity(0.7)), // 🌟 Label အရောင်
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: dialogTextColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: dialogTextColor),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("မလုပ်တော့ပါ",
                  style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.trim() == savedPassword) {
                  Navigator.pop(context);
                  setState(() {
                    _isVerified = true;
                    _isLoading = false;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Password မှားယွင်းနေပါသည်။"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("ဝင်မည်"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDarkMode = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    // 🌟 Blur box background အရောင်များ (Dark Theme ဆိုရင် အမည်းအလင်း၊ Default ဆိုရင် အဖြူအလင်း)
    Color boxBgColor = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.white.withOpacity(0.4);

    // Password မစစ်ဆေးရသေးပါက Loading ပြသမည်
    if (_isLoading) {
      return Container(
        decoration: themeProvider.getBackgroundDecoration(),
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Password တစ်ကြိမ်စစ်ဆေးပြီးမှသာ အကြောင်းအရာကို ပြသမည်
    if (!_isVerified) {
      return Container(
        decoration: themeProvider.getBackgroundDecoration(),
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Text(
              "Security verification required",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    // Password မှန်ကန်မှသာ အောက်ပါ UI ကို ပြသမည်
    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("Earn & Reward Dashboard",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 💰 🌟 Balance StreamBuilder
                    StreamBuilder<DocumentSnapshot>(
                      stream: (currentUid != null)
                          ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUid)
                              .snapshots()
                          : null,
                      builder: (context, snapshot) {
                        num balance = 0;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          var userData =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          balance = userData?['balance'] ?? 0;
                        }

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.green, Colors.teal],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("စုစုပေါင်း ရရှိငွေ (Total Earnings)",
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 8),
                              Text("$balance MMK",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 15),
                              const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Earn Money & Rewards",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 25),

                    Text("Monetization Tools",
                        style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),

                    // 🌟 Deposit Option
                    _buildBlurRewardOption(
                      context: context,
                      boxBgColor: boxBgColor,
                      icon: Icons.account_balance_wallet,
                      title: "အကောင့်ထဲငွေသွင်းရန် (Deposit)",
                      subtitle: "သင့်အကောင့်လက်ကျန်ငွေဖြည့်ရန် ငွေသွင်းပါ။",
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const DepositRequestPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // 🌟 Withdraw Option
                    _buildBlurRewardOption(
                      context: context,
                      boxBgColor: boxBgColor,
                      icon: Icons.account_balance,
                      title: "ငွေထုတ်ယူရန် (Withdraw)",
                      subtitle: "သင့်အကောင့်ထဲသို့ ငွေလွှဲရန် တောင်းဆိုပါ။",
                      textColor: textColor,
                      onTap: () async {
                        final String? uid =
                            FirebaseAuth.instance.currentUser?.uid;
                        if (uid == null) return;

                        final userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .get();

                        if (!mounted) return;

                        final userData = userDoc.data() ?? <String, dynamic>{};
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentRequestPage(
                              currentBalance: userData['balance'] ?? 0,
                              savedPassword: userData['rewardPassword'] ?? '',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // 🌟 Analytics Option
                    _buildBlurRewardOption(
                      context: context,
                      boxBgColor: boxBgColor,
                      icon: Icons.bar_chart,
                      title: "ဝင်ငွေစာရင်းအချက်အလက် (Analytics)",
                      subtitle:
                          "ဗီဒီယို တစ်ခုချင်းစီ၏ ဝင်ငွေများကို ကြည့်ရှုပါ။",
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const IncomeAnalysisPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // 🌟 History Option
                    _buildBlurRewardOption(
                      context: context,
                      boxBgColor: boxBgColor,
                      icon: Icons.history,
                      title: "ငွေထုတ်ယူမှု မှတ်တမ်း (Withdraw History)",
                      subtitle:
                          "တောင်းဆိုထားသော ငွေထုတ်မှုအခြေအနေများကို ကြည့်ရှုပါ။",
                      textColor: textColor,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WithdrawHistoryPage(),
                          ),
                        );
                      },
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

  // 🌟 Blur Effect ပါဝင်သည့် Custom Option Widget
  Widget _buildBlurRewardOption({
    required BuildContext context,
    required Color boxBgColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: boxBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(icon, color: Colors.green, size: 30),
            title: Text(title,
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            subtitle: Text(subtitle,
                style:
                    TextStyle(fontSize: 12, color: textColor.withOpacity(0.7))),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16, color: textColor.withOpacity(0.7)),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
