// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:provider/provider.dart'; // 🌟 Provider ချိတ်ရန်
import 'package:karma/utilis/theme_provider.dart'; // 🌟 ThemeProvider ချိတ်ရန်

class PaymentRequestPage extends StatefulWidget {
  final num currentBalance;
  final String savedPassword;

  const PaymentRequestPage({
    super.key,
    required this.currentBalance,
    required this.savedPassword,
  });

  @override
  State<PaymentRequestPage> createState() => _PaymentRequestPageState();
}

class _PaymentRequestPageState extends State<PaymentRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _nrcController = TextEditingController();

  String _selectedMethod = 'KBZPay';
  bool _isLoading = false;
  bool _isLoadingNrc = true;

  @override
  void initState() {
    super.initState();
    _fetchUserNrc();
  }

  Future<void> _fetchUserNrc() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        String nrc = data?['nrcNumber'] ?? '';
        setState(() {
          _nrcController.text = nrc;
          _isLoadingNrc = false;
        });
      } else {
        setState(() => _isLoadingNrc = false);
      }
    } catch (e) {
      setState(() => _isLoadingNrc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 Theme Provider များကို ခေါ်ယူခြင်း
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();
    Color cardColor = isDark ? Colors.grey[900]! : Colors.white;

    return Container(
      decoration: themeProvider
          .getBackgroundDecoration(), // 🌟 Custom Background ထည့်သွင်းခြင်း
      child: Scaffold(
        backgroundColor: Colors
            .transparent, // 🌟 Background ပေါ်လာစေရန် Transparent လုပ်ခြင်း
        appBar: AppBar(
          title: Text(
            'ငွေထုတ်မည်',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: SafeArea(
          child: _isLoadingNrc
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BannerAdWidget(),
                        const SizedBox(height: 16),

                        // 💰 လက်ရှိ Balance ပြသရန် Container
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(isDark ? 0.7 : 0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "ထုတ်ယူနိုင်သော လက်ကျန်ငွေ",
                                style: TextStyle(
                                    fontSize: 13,
                                    color: textColor.withOpacity(0.7)),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "${widget.currentBalance} MMK",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ငွေပမာဏ
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'ငွေပမာဏ (MMK)',
                            labelStyle:
                                TextStyle(color: textColor.withOpacity(0.8)),
                            helperText:
                                'အနည်းဆုံး ထုတ်ယူနိုင်သည့်ပမာဏ - 5,000 MMK',
                            helperStyle:
                                TextStyle(color: textColor.withOpacity(0.6)),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: textColor.withOpacity(0.3)),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'ငွေပမာဏ ထည့်ပါ';
                            }
                            final amount = num.tryParse(value.trim());
                            if (amount == null || amount <= 0) {
                              return 'မှန်ကန်သော ငွေပမာဏကို ထည့်ပါ';
                            }
                            if (amount < 5000) {
                              return 'အနည်းဆုံး 5,000 MMK ရှိရပါမည်';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ငွေထုတ်မည့် နည်းလမ်း
                        DropdownButtonFormField<String>(
                          value: _selectedMethod,
                          dropdownColor: cardColor,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'ငွေထုတ်မည့် နည်းလမ်း',
                            labelStyle:
                                TextStyle(color: textColor.withOpacity(0.8)),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: textColor.withOpacity(0.3)),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'KBZPay', child: Text('KBZPay')),
                            DropdownMenuItem(
                                value: 'WavePay', child: Text('WavePay')),
                            DropdownMenuItem(
                                value: 'AYA Pay', child: Text('AYA Pay')),
                            DropdownMenuItem(
                                value: 'Bank Transfer',
                                child: Text('Bank Transfer')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedMethod = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // NRC နံပါတ်
                        TextFormField(
                          controller: _nrcController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'NRC နံပါတ်',
                            labelStyle:
                                TextStyle(color: textColor.withOpacity(0.8)),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: textColor.withOpacity(0.3)),
                            ),
                            helperText:
                                'Monetization လျှောက်ထားစဉ်က အတည်ပြုခဲ့သော NRC\n'
                                'Monetization မလျှောက်ထားသူများ မိမိ NRC ထည့်ပေးပါ',
                            helperStyle:
                                TextStyle(color: textColor.withOpacity(0.6)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'NRC နံပါတ် ထည့်ပါ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // အကောင့်အမည်
                        TextFormField(
                          controller: _accountNameController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'အကောင့်အမည်',
                            labelStyle:
                                TextStyle(color: textColor.withOpacity(0.8)),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: textColor.withOpacity(0.3)),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'အကောင့်အမည် ထည့်ပါ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // အကောင့်နံပါတ်
                        TextFormField(
                          controller: _accountNumberController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'ဖုန်းနံပါတ် / အကောင့်နံပါတ်',
                            labelStyle:
                                TextStyle(color: textColor.withOpacity(0.8)),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: textColor.withOpacity(0.3)),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'အကောင့်နံပါတ် ထည့်ပါ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // တောင်းဆိုမည့် ခလုတ်
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () => _submitPaymentRequest(
                                  widget.currentBalance, widget.savedPassword),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('တောင်းဆိုမည်',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'သတိပြုရန် - ပုံမှန် User များ တစ်လလျှင် ၁ ကြိမ်သာ ထုတ်ယူနိုင်ပါသည်။ (Golden Mark User များ - ၃ ကြိမ်)',
                          style: TextStyle(
                            color: textColor.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _submitPaymentRequest(
      num currentBalance, String savedPassword) async {
    if (!_formKey.currentState!.validate()) return;

    num requestedAmount = num.tryParse(_amountController.text.trim()) ?? 0;

    if (requestedAmount > currentBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("သင့်အကောင့်တွင် ငွေပမာဏ မလုံလောက်ပါ။"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (requestedAmount < 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("အနည်းဆုံး ငွေထုတ်ယူနိုင်သည့်ပမာဏမှာ 5,000 MMK ဖြစ်ပါသည်။"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;

        String monetizationStatus = data?['monetizationStatus'] ?? 'none';
        String savedNrc = data?['nrcNumber'] ?? '';
        String savedBank = data?['bankAccount'] ?? '';
        String role = data?['role'] ?? 'user';

        String inputNrc = _nrcController.text.trim();
        String inputBank = _accountNumberController.text.trim();

        // 🌟 Monetization Approved ဖြစ်ပြီးသားသူ ဖြစ်မှသာ ရှေ့က NRC/Bank နဲ့ တိုက်စစ်မည်
        if (monetizationStatus == 'approved') {
          if (savedNrc.isNotEmpty && inputNrc != savedNrc) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "ထည့်သွင်းထားသော NRC နံပါတ်သည် Monetization လျှောက်ထားစဉ်က NRC နှင့် မကိုက်ညီပါ။"),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          if (savedBank.isNotEmpty && inputBank != savedBank) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "ထည့်သွင်းထားသော ဘဏ်အကောင့်/ဖုန်းနံပါတ်သည် Monetization လျှောက်ထားစဉ်က အကောင့်နှင့် မကိုက်ညီပါ။"),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        // 🌟 ဝင်ငွေထုတ်ယူမှု လစဉ် ကန့်သတ်ချက် (Monthly Limit) - Index ပြဿနာ လုံးဝမရှိစေရန် Dart ဘက်မှ စစ်ထုတ်ခြင်း
        DateTime now = DateTime.now();
        int currentYear = now.year;
        int currentMonth = now.month;

        // User တစ်ယောက်တည်းရဲ့ request အားလုံးကို ဆွဲထုတ်မည် (Index မလိုပါ)
        QuerySnapshot userRequests = await FirebaseFirestore.instance
            .collection('payment_requests')
            .where('uid', isEqualTo: user.uid)
            .get();

        // ယခုလ (Current Month & Year) အတွင်း တောင်းဆိုထားမှုကိုသာ အရေအတွက် တွက်မည်
        int requestCountThisMonth = 0;
        for (var doc in userRequests.docs) {
          var reqData = doc.data() as Map<String, dynamic>;
          Timestamp? timestamp = reqData['createdAt'] as Timestamp?;
          if (timestamp != null) {
            DateTime reqDate = timestamp.toDate();
            if (reqDate.year == currentYear && reqDate.month == currentMonth) {
              requestCountThisMonth++;
            }
          }
        }

        // Role အလိုက် ထုတ်ယူခွင့် အကြိမ်ရေ သတ်မှတ်ခြင်း (Golden Mark, Admin, VIP, Gold User = 3 ကြိမ်၊ ကျန်သူ = 1 ကြိမ်)
        bool isGoldenMark = [
              'admin',
              'vip',
              'team_karma',
              'gold_user',
              'approved'
            ].contains(role.toLowerCase()) ||
            monetizationStatus == 'approved';

        int allowedLimit = isGoldenMark ? 3 : 1;

        if (requestCountThisMonth >= allowedLimit) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isGoldenMark
                    ? "ယခုလအတွက် ငွေထုတ်ယူခွင့် ကန့်သတ်ချက် (၃ ကြိမ်) ပြည့်သွားပါပြီ။"
                    : "ယခုလအတွက် ငွေထုတ်ယူခွင့် (၁ ကြိမ်) ပြည့်သွားပါပြီ။ (Golden Mark ရယူပါက တစ်လလျှင် ၃ ကြိမ်အထိ ထုတ်နိုင်ပါသည်)",
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print("Validation Error: $e");
      // Error တက်ရင်တောင် လုံခြုံရေးအရ ဆက်မသွားစေရန် တားမည်
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("စစ်ဆေးရာတွင် အမှားအယွင်းရှိသည်: $e"),
            backgroundColor: Colors.red),
      );
      return;
    }

    _showPasswordVerificationDialog(requestedAmount, savedPassword);
  }

  void _showPasswordVerificationDialog(
      num requestedAmount, String savedPassword) {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("လုံခြုံရေး အတည်ပြုရန်"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "ငွေထုတ်ယူမှု တောင်းဆိုမှုကို အတည်ပြုရန် သင့် Earn Password ကို ရိုက်ထည့်ပါ။"),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Password ထည့်ရန်",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("မလုပ်တော့ပါ", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.trim() == savedPassword) {
                Navigator.pop(context);
                await _sendRequestToFirestore(requestedAmount);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Password မှားယွင်းနေပါသည်။"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("အတည်ပြုမည်"),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequestToFirestore(num requestedAmount) async {
    setState(() => _isLoading = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('payment_requests').add({
        'uid': user.uid,
        'email': user.email ?? '',
        'amount': requestedAmount,
        'paymentMethod': _selectedMethod,
        'nrcNumber': _nrcController.text.trim(),
        'accountName': _accountNameController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      DocumentReference userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);
        if (snapshot.exists) {
          num currentBalance = snapshot.get('balance') ?? 0;
          num newBalance = currentBalance - requestedAmount;
          if (newBalance < 0) newBalance = 0;

          transaction.update(userRef, {'balance': newBalance});
        }
      });

      if (!mounted) return;

      setState(() => _isLoading = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("တောင်းဆိုမှု အောင်မြင်ပါသည်"),
          content: const Text(
            "ငွေထုတ်ယူရန် တောင်းဆိုမှုကို အောင်မြင်စွာ ပို့လိုက်ပါပြီ။ သင့်လက်ကျန်ငွေထဲမှ ဖြတ်တောက်ပြီးဖြစ်ပါသည်။",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("အိုကေ"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("တောင်းဆိုမှု ပို့ရာတွင် မှားယွင်းနေပါသည်: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _nrcController.dispose();
    super.dispose();
  }
}
