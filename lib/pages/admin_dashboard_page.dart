// ignore_for_file: use_build_context_synchronously, unused_field

import 'package:flutter/material.dart';
import 'package:karma/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboardPage extends StatefulWidget {
  final String userRole;
  const AdminDashboardPage({super.key, required this.userRole});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isAuthorized = false;
  bool _isSettingPassword = false;

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Password ပြောင်းရန် Controllers များ
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  // 🔗 Google Form Responses (Google Sheets) Links
  // (အကို့ရဲ့ Drive / Sheet Link များကို ဤနေရာတွင် လဲလှယ် ထည့်သွင်းနိုင်ပါသည်)
  final String goldenSheetsUrl =
      'https://docs.google.com/spreadsheets/d/1_EXMPLE_GOLDEN_SHEET_ID/edit';
  final String depositSheetsUrl =
      'https://docs.google.com/spreadsheets/d/1_EXMPLE_DEPOSIT_SHEET_ID/edit';

  @override
  void initState() {
    super.initState();
    _checkAdminPasswordExists();
  }

  // 🌐 External Link (Google Sheet / Browser) ဖွင့်ပေးမည့် ဖန်းရှင်း
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
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

  // Password ရှိမရှိ စစ်ဆေးခြင်း
  Future<void> _checkAdminPasswordExists() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedPassword = prefs.getString('admin_dashboard_password');

    setState(() {
      if (savedPassword == null || savedPassword.isEmpty) {
        _isSettingPassword = true;
      } else {
        _isSettingPassword = false;
      }
    });
  }

  // Password အသစ်သတ်မှတ်ခြင်း (ပထမအကြိမ်)
  Future<void> _saveNewPassword() async {
    bool isMm = isMyanmarNotifier.value;
    if (_passwordController.text.isEmpty ||
        _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'စကားဝှက်များ မကိုက်ညီပါ သို့မဟုတ် ကွက်လပ်ဖြစ်နေပါသည်'
                : 'Passwords do not match or are empty.',
          ),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_dashboard_password', _passwordController.text);

    setState(() {
      _isSettingPassword = false;
      _isAuthorized = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isMm
              ? 'Admin Password ကို အောင်မြင်စွာ မှတ်သားပြီးပါပြီ'
              : 'Admin password saved successfully.',
        ),
      ),
    );
  }

  // Password ဝင်ရောက်စစ်ဆေးခြင်း
  Future<void> _verifyPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedPassword = prefs.getString('admin_dashboard_password');

    if (_passwordController.text == savedPassword) {
      setState(() {
        _isAuthorized = true;
      });
    } else {
      bool isMm = isMyanmarNotifier.value;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm ? 'စကားဝှက် အမှားဖြစ်နေပါသည်' : 'Incorrect password.',
          ),
        ),
      );
    }
  }

  // Admin Password ပြန်ပြောင်းရန် Function
  Future<void> _changePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedPassword = prefs.getString('admin_dashboard_password');
    bool isMm = isMyanmarNotifier.value;

    if (_oldPasswordController.text != savedPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'လက်ရှိစကားဝှက် အမှားဖြစ်နေပါသည်'
                : 'Current password is incorrect.',
          ),
        ),
      );
      return;
    }

    if (_newPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'စကားဝှက်အသစ် ထည့်ရန်လိုအပ်ပါသည်'
                : 'New password is required.',
          ),
        ),
      );
      return;
    }

    await prefs.setString(
        'admin_dashboard_password', _newPasswordController.text);

    _oldPasswordController.clear();
    _newPasswordController.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isMm
              ? 'Admin Password ကို အောင်မြင်စွာ ပြောင်းလဲပြီးပါပြီ'
              : 'Admin password changed successfully.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();
    Color cardColor = isDark ? Colors.grey[900]! : Colors.white;

    // ၁။ Password အသစ်သတ်မှတ်ရန် မျက်နှာပြင်
    if (_isSettingPassword) {
      return Container(
        decoration: themeProvider.getBackgroundDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Text(
                  isMm
                      ? 'Admin Password အသစ်ဖန်တီးရန်'
                      : 'Create New Admin Password',
                  style: TextStyle(color: textColor),
                );
              },
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isMm
                          ? 'Admin Dashboard သို့ ဝင်ရန် Password အသစ် သတ်မှတ်ပေးပါ'
                          : 'Please set a new password to access the Admin Dashboard.',
                      style: TextStyle(fontSize: 16, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: isMm ? 'Password အသစ်' : 'New Password',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: isMm
                            ? 'Password ကို အတည်ပြုပါ'
                            : 'Confirm Password',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveNewPassword,
                      child: Text(
                        isMm ? 'Password ကို မှတ်သားမည်' : 'Save Password',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    // ၂။ Password တောင်းခံသည့် မျက်နှာပြင် (Login)
    if (!_isAuthorized) {
      return Container(
        decoration: themeProvider.getBackgroundDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Text('Admin Login', style: TextStyle(color: textColor)),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings,
                    size: 70, color: Colors.blue),
                const SizedBox(height: 20),
                ValueListenableBuilder<bool>(
                  valueListenable: isMyanmarNotifier,
                  builder: (context, isMm, child) {
                    return TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: isMm
                            ? 'Admin Password ထည့်ပါ'
                            : 'Enter Admin Password',
                        border: const OutlineInputBorder(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<bool>(
                  valueListenable: isMyanmarNotifier,
                  builder: (context, isMm, child) {
                    return ElevatedButton(
                      onPressed: _verifyPassword,
                      child: Text(isMm ? 'ဝင်ရောက်မည်' : 'Login'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ၃။ အဓိက Admin Dashboard မျက်နှာပြင်
    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: Text('Admin Dashboard',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: Icon(Icons.logout, color: textColor),
              onPressed: () {
                setState(() {
                  _isAuthorized = false;
                });
              },
            )
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Text(
                  isMm
                      ? 'ကြိုဆိုပါတယ် (Admin / Team)'
                      : 'Welcome (Admin / Team)',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                );
              },
            ),
            const SizedBox(height: 20),

            // --- 🌟 Users များအားလုံး၏ စုစုပေါင်း Balance ကို ပြသရန် Widget ---
            Card(
              color: cardColor,
              margin: const EdgeInsets.only(bottom: 20),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Text(
                            isMm
                                ? 'စုစုပေါင်း အသုံးပြုသူ လက်ကျန်ငွေ: 0 K-Points'
                                : 'Total Users Balance: 0 K-Points',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor),
                          );
                        },
                      );
                    }

                    double totalBalance = 0.0;
                    for (var doc in snapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      var balanceVal = data['balance'];
                      if (balanceVal != null) {
                        totalBalance += (balanceVal is int)
                            ? balanceVal.toDouble()
                            : (balanceVal as double);
                      }
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable: isMyanmarNotifier,
                              builder: (context, isMm, child) {
                                return Text(
                                  isMm
                                      ? 'စုစုပေါင်း အသုံးပြုသူများ လက်ကျန်ငွေ'
                                      : 'Total Users Balance',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: textColor.withOpacity(0.7)),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalBalance.toStringAsFixed(2)} K-Points',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.account_balance_wallet,
                            size: 40, color: Colors.greenAccent),
                      ],
                    );
                  },
                ),
              ),
            ),

            // --- 📊 Google Form Responses (Google Sheets) စီမံခန့်ခွဲရန် ခလုတ်များ ---
            Card(
              color: cardColor,
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.table_chart_rounded, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          "Google Form Responses (Google Sheets)",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Golden Mark နှင့် Deposit လျှောက်လွှာများကို Google Drive သို့ ပေးပို့ထားသော Google Sheets ထဲတွင် တိုက်ရိုက် စစ်ဆေးနိုင်ပါသည် -",
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🌟 Golden Mark Responses Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: () => _launchUrl(goldenSheetsUrl),
                      icon: const Icon(Icons.workspace_premium),
                      label: const Text(
                          "Golden Mark စာရင်း ကြည့်ရန် (Google Sheet)"),
                    ),
                    const SizedBox(height: 10),

                    // 🌟 Deposit Requests Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: () => _launchUrl(depositSheetsUrl),
                      icon: const Icon(Icons.monetization_on),
                      label:
                          const Text("Deposit စာရင်း ကြည့်ရန် (Google Sheet)"),
                    ),
                  ],
                ),
              ),
            ),

            // --- ADMIN ဖြစ်မှသာ Password ပြောင်းရန် Menu ပေါ်လာမည် ---
            if (widget.userRole.trim().toLowerCase() == 'admin') ...[
              Card(
                color: cardColor,
                child: ExpansionTile(
                  leading: Icon(Icons.lock_reset, color: textColor),
                  title: ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return Text(
                        isMm
                            ? 'Admin Password ပြန်ပြောင်းရန်'
                            : 'Change Admin Password',
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Column(
                            children: [
                              TextField(
                                controller: _oldPasswordController,
                                obscureText: true,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: isMm
                                      ? 'လက်ရှိ Password ထည့်ပါ'
                                      : 'Enter Current Password',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _newPasswordController,
                                obscureText: true,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: isMm
                                      ? 'Password အသစ်ထည့်ပါ'
                                      : 'Enter New Password',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _changePassword,
                                child: Text(
                                  isMm
                                      ? 'Password ပြောင်းမည်'
                                      : 'Change Password',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Text(
                  isMm
                      ? 'ငွေထုတ်ယူမှု တောင်းဆိုချက်များ (Withdraw Requests):'
                      : 'Withdraw Requests:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // 🌟 Firestore မှ payment_requests (Withdrawal) များကို Stream ဖြင့် ဆွဲထုတ်ပြသခြင်း
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('payment_requests')
                  .where('status', isEqualTo: 'pending')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: isMyanmarNotifier,
                      builder: (context, isMm, child) {
                        return Text(
                          isMm
                              ? 'စစ်ဆေးရန် ငွေထုတ်ယူမှု တောင်းဆိုချက် မရှိသေးပါ'
                              : 'No pending withdrawal requests to review',
                          style: TextStyle(color: textColor.withOpacity(0.7)),
                        );
                      },
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    String docId = doc.id;
                    String paymentMethod = data['paymentMethod'] ?? 'KBZPay';
                    num amount = data['amount'] ?? 0;
                    String accountNumber = data['accountNumber'] ?? '';
                    String accountName = data['accountName'] ?? '';
                    String userId = data['uid'] ?? '';

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  paymentMethod,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "$amount K-Points",
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Text("User UID: $userId",
                                style: TextStyle(
                                    color: textColor.withOpacity(0.6),
                                    fontSize: 12)),
                            const SizedBox(height: 4),
                            ValueListenableBuilder<bool>(
                              valueListenable: isMyanmarNotifier,
                              builder: (context, isMm, child) {
                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isMm
                                          ? 'အမည်: $accountName'
                                          : 'Name: $accountName',
                                      style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    Text(
                                      isMm
                                          ? 'အကောင့် နံပါတ်: $accountNumber'
                                          : 'Account No: $accountNumber',
                                      style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 15),
                            ValueListenableBuilder<bool>(
                              valueListenable: isMyanmarNotifier,
                              builder: (context, isMm, child) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .collection('payment_requests')
                                            .doc(docId)
                                            .update({'status': 'rejected'});

                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isMm
                                                  ? "ငွေထုတ်ယူမှုကို ပယ်ချလိုက်ပါပြီ။"
                                                  : "Withdrawal request rejected.",
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.close,
                                          color: Colors.red),
                                      label: Text(
                                        isMm ? 'ပယ်ချမည်' : "Reject",
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .collection('payment_requests')
                                            .doc(docId)
                                            .update({'status': 'approved'});

                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isMm
                                                  ? "ငွေထုတ်ယူမှုကို အောင်မြင်စွာ အတည်ပြုလိုက်ပါပြီ။"
                                                  : "Withdrawal approved successfully.",
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.check,
                                          color: Colors.white),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green),
                                      label: Text(
                                        isMm ? 'အတည်ပြုမည်' : "Approve",
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Text(
                  isMm
                      ? 'ပို့စ် Report တောင်းဆိုချက်များ (Reported Posts):'
                      : 'Reported Posts:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // 🌟 Firestore မှ reports များကို Stream ဖြင့် ဆွဲထုတ်ပြသခြင်း
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('status', isEqualTo: 'pending')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      isMyanmarNotifier.value
                          ? 'စစ်ဆေးရန် Report တင်ထားခြင်း မရှိသေးပါ'
                          : 'No pending reports to review',
                      style: TextStyle(color: textColor.withOpacity(0.7)),
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    String docId = doc.id;
                    String postId = data['postId'] ?? '';
                    String reason = data['reason'] ?? 'အကြောင်းပြချက်မရှိပါ';
                    String postContent = data['postContent'] ?? '';

                    return Card(
                      color: cardColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable: isMyanmarNotifier,
                              builder: (context, isMm, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isMm
                                              ? "ပို့စ် Report တိုင်ကြားချက်"
                                              : "Post Report",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.redAccent),
                                        ),
                                        Chip(
                                          label: Text(
                                            isMm ? "စောင့်ဆိုင်းဆဲ" : "PENDING",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12),
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Text(
                                      isMm
                                          ? "အကြောင်းပြချက်: $reason"
                                          : "Reason: $reason",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textColor),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      isMm
                                          ? "ပို့စ်အနှစ်ချုပ်: $postContent"
                                          : "Post Summary: $postContent",
                                      style: TextStyle(
                                          color: textColor.withOpacity(0.8)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            await FirebaseFirestore.instance
                                                .collection('reports')
                                                .doc(docId)
                                                .update(
                                                    {'status': 'dismissed'});
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  isMm
                                                      ? "Report ကို ပယ်ဖျက်လိုက်ပါပြီ။"
                                                      : "Report dismissed.",
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.close,
                                              color: Colors.grey),
                                          label: Text(
                                            isMm ? 'လျစ်လျူရှုမည်' : "Ignore",
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            if (postId.isNotEmpty) {
                                              await FirebaseFirestore.instance
                                                  .collection('posts')
                                                  .doc(postId)
                                                  .delete();
                                            }
                                            await FirebaseFirestore.instance
                                                .collection('reports')
                                                .doc(docId)
                                                .update({'status': 'resolved'});

                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  isMm
                                                      ? "ပို့စ်ကို ဖျက်ဆီးပြီး Report ကို ရှင်းလင်းပြီးပါပြီ။"
                                                      : "Post deleted and report resolved.",
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.delete,
                                              color: Colors.white),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red),
                                          label: Text(
                                            isMm
                                                ? 'ပို့စ်ဖျက်မည်'
                                                : "Delete Post",
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
