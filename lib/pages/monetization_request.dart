// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:karma/main.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/navigation_helper.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/services/r2_service.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
// 🌟 Earn & Reward Page ကို import လုပ်ရန် (ကိုယ့်ရဲ့ path အမှန်အတိုင်းထည့်ပါ)
import 'package:karma/pages/earn_and_reward_page.dart';
import 'package:karma/pages/golden_verified_page.dart';

class MonetizationRequestPage extends StatefulWidget {
  const MonetizationRequestPage({super.key});

  @override
  State<MonetizationRequestPage> createState() =>
      _MonetizationRequestPageState();
}

class _MonetizationRequestPageState extends State<MonetizationRequestPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Follower စစ်ဆေးရန် Variables (50k သို့ သတ်မှတ်ထားသည်)
  bool _isLoadingFollowers = true;
  int _currentFollowers = 0;
  final int _requiredFollowers = 50000;

  final TextEditingController _nrcController = TextEditingController();
  final TextEditingController _bankController = TextEditingController();

  File? _nrcImage;
  bool _isAgreed = false;
  bool _isSubmitting = false;

  // Status စစ်ဆေးရန် Variables
  bool _isLoadingStatus = true;
  bool _isGoldenUser = false;
  String _monetizationStatus =
      'none'; // 'none', 'pending', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    _checkUserStatus(); // 🌟 စဝင်လာချင်းမှာ User Status နဲ့ Follower အရေအတွက်ပါ အတူတူ စစ်ဆေးမည်
  }

  // 🌟 User ရဲ့ role, monetizationStatus နှင့် follower အရေအတွက်ကို Firestore ကနေ စစ်ဆေးခြင်း
  Future<void> _checkUserStatus() async {
    if (user == null) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        String role = data?['role'] ?? '';
        String status = data?['monetizationStatus'] ?? 'none';

        // Database ထဲမှ user ၏ follower အရေအတွက်ကို ရယူခြင်း (မရှိသေးပါက 0 ဟု သတ်မှတ်မည်)
        int followers = data?['followersCount'] ?? data?['followers'] ?? 0;

        // Golden Mark ရှိမရှိ စစ်ဆေးခြင်း
        String normalizedRole = role.trim().toLowerCase();
        bool isGolden = (normalizedRole == 'admin' ||
            normalizedRole == 'team_karma' ||
            normalizedRole == 'vip' ||
            normalizedRole == 'gold_user');

        setState(() {
          _isGoldenUser = isGolden;
          _monetizationStatus = status;
          _currentFollowers = followers;
          _isLoadingStatus = false;
          _isLoadingFollowers = false;
        });

        // 🚀 အကယ်၍ Already Approved ဖြစ်ပြီးသားဆိုရင် Earn & Reward Page ဆီသို့ တန်းပို့မည်
        if (status == 'approved') {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const EarnAndRewardPage()),
          );
        }
      } else {
        setState(() {
          _isLoadingStatus = false;
          _isLoadingFollowers = false;
        });
      }
    } catch (e) {
      print("Status စစ်ဆေးရာတွင် အမှားရှိသည်: $e");
      setState(() {
        _isLoadingStatus = false;
        _isLoadingFollowers = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _nrcImage = File(pickedFile.path));
    }
  }

  @override
  void dispose() {
    _nrcController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_nrcController.text.trim().isEmpty ||
        _bankController.text.trim().isEmpty ||
        _nrcImage == null ||
        !_isAgreed) {
      final isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? "ကျေးဇူးပြု၍ အချက်အလက်များအားလုံး ဖြည့်သွင်းပါ၊ NRC ပုံထည့်ပါ နှင့် စည်းကမ်းချက်ကို သဘောတူပါ။"
                : "Please fill in all details, attach your NRC image, and agree to the terms and conditions.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (user == null) return;

      // R2 ကို ပုံပို့ပြီး URL ရယူခြင်း
      String? nrcImageUrl =
          await R2Service.uploadFile(_nrcImage!, 'monetization_requests');

      if (nrcImageUrl == null) {
        final isMm = isMyanmarNotifier.value;
        throw Exception(
          isMm
              ? "NRC ပုံကို R2 သို့ တင်၍မရပါ ဆက်သွယ်မှု စစ်ဆေးပါ။"
              : "Failed to upload NRC image to R2. Please check your connection.",
        );
      }

      // Monetization Requests Collection ထဲသို့ အသစ်ထည့်ခြင်း
      await FirebaseFirestore.instance.collection('monetization_requests').add({
        'uid': user!.uid,
        'nrcNumber': _nrcController.text.trim(),
        'nrcImageUrl': nrcImageUrl,
        'bankAccount': _bankController.text.trim(),
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // User's monetizationStatus ကို pending သို့ ပြောင်းခြင်း
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'monetizationStatus': 'pending',
        'nrcNumber': _nrcController.text.trim(),
        'bankAccount':
            _bankController.text.trim(), // 👈 ဤနေရာတွင် ဘဏ်အကောင့်ပါ သိမ်းမည်
      });

      if (!mounted) return;
      final isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? "Monetization လျှောက်လွှာ ပို့ပြီးပါပြီ။ Admin စစ်ဆေးမှုကို စောင့်ဆိုင်းပါ။"
                : "Monetization application submitted successfully. Please wait for admin review.",
          ),
        ),
      );
      NavigationHelper.pop(context);
    } catch (e) {
      final isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm ? "အမှားအယွင်း ရှိနေပါသည်: $e" : "An error occurred: $e",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
                isMm ? "Monetization လျှောက်ထားရန်" : "Apply for Monetization",
                style: TextStyle(color: textColor),
              );
            },
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: (_isLoadingStatus || _isLoadingFollowers)
            ? const Center(child: CircularProgressIndicator())
            : !_isGoldenUser
                ? Center(
                    // 🌟 1. Golden Mark မရှိသေးပါက ပြသမည့် UI
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 60, color: Colors.amber),
                          const SizedBox(height: 16),
                          ValueListenableBuilder<bool>(
                            valueListenable: isMyanmarNotifier,
                            builder: (context, isMm, child) {
                              return Text(
                                isMm
                                    ? "Monetization လျှောက်ထားရန် Golden Mark (Verified) မဖြစ်မနေ လိုအပ်ပါသည်။"
                                    : "Golden Mark (Verified) is mandatory to apply for Monetization.",
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<bool>(
                            valueListenable: isMyanmarNotifier,
                            builder: (context, isMm, child) {
                              return Text(
                                isMm
                                    ? "ကျေးဇူးပြု၍ ပထမဦးစွာ Golden Mark လျှောက်ထားပါ။"
                                    : "Please apply for Golden Mark first.",
                                style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                    fontSize: 14),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                          const SizedBox(height: 25),

                          // 🚀 Golden Mark လျှောက်မည့် စာမျက်နှာသို့ သွားရန် ခလုတ်
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black87,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const GoldenVerifiedPage(),
                                  ),
                                );
                              },
                              child: ValueListenableBuilder<bool>(
                                valueListenable: isMyanmarNotifier,
                                builder: (context, isMm, child) {
                                  return Text(
                                      isMm
                                          ? "Golden Mark လျှောက်ထားရန်"
                                          : "Apply for Golden Mark",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold));
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 🚪 နောက်မှလုပ်မည် (ထွက်ရန်) ခလုတ်
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: textColor.withOpacity(0.5)),
                              ),
                              onPressed: () => NavigationHelper.pop(context),
                              child: ValueListenableBuilder<bool>(
                                valueListenable: isMyanmarNotifier,
                                builder: (context, isMm, child) {
                                  return Text(isMm ? "နောက်မှလုပ်မည်" : "Later",
                                      style: TextStyle(color: textColor));
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _monetizationStatus == 'pending'
                    ? Center(
                        // ⏳ 2. Pending ဖြစ်နေစဉ် ပြမည့် UI
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.hourglass_top_rounded,
                                  size: 70, color: Colors.orange),
                              const SizedBox(height: 16),
                              ValueListenableBuilder<bool>(
                                valueListenable: isMyanmarNotifier,
                                builder: (context, isMm, child) {
                                  return Text(
                                    isMm
                                        ? "သင်၏ Monetization လျှောက်ထားမှုကို စစ်ဆေးဆဲ ဖြစ်ပါသည်။"
                                        : "Your Monetization application is currently under review.",
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              ValueListenableBuilder<bool>(
                                valueListenable: isMyanmarNotifier,
                                builder: (context, isMm, child) {
                                  return Text(
                                    isMm
                                        ? "Admin ဘက်မှ အတည်ပြုပေးသည်အထိ ခေတ္တစောင့်ဆိုင်းပေးပါရန်။"
                                        : "Please wait patiently until the admin reviews and approves it.",
                                    style: TextStyle(
                                        color: textColor.withOpacity(0.7),
                                        fontSize: 14),
                                    textAlign: TextAlign.center,
                                  );
                                },
                              ),
                              const SizedBox(height: 25),
                              ElevatedButton(
                                onPressed: () => NavigationHelper.pop(context),
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: isMyanmarNotifier,
                                  builder: (context, isMm, child) {
                                    return Text(isMm
                                        ? "နောက်သို့ ပြန်သွားရန်"
                                        : "Go Back");
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ❌ Rejected ဖြစ်ခဲ့ပါက အကြောင်းပြချက်
                                  if (_monetizationStatus == 'rejected')
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 20),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.red),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Colors.red),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: ValueListenableBuilder<bool>(
                                              valueListenable:
                                                  isMyanmarNotifier,
                                              builder: (context, isMm, child) {
                                                return Text(
                                                  isMm
                                                      ? "သင်၏ ယခင်လျှောက်လွှာ ငြင်းပယ်ခံခဲ့ရပါသည်။ အချက်အလက်များ ပြန်လည်စစ်ဆေးပြီး ထပ်မံလျှောက်ထားနိုင်ပါသည်။"
                                                      : "Your previous application was rejected. Please review your information and apply again.",
                                                  style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 13),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // 📊 Follower အခြေအနေပြ Card
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: _currentFollowers >=
                                              _requiredFollowers
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _currentFollowers >=
                                                _requiredFollowers
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _currentFollowers >=
                                                  _requiredFollowers
                                              ? Icons.check_circle
                                              : Icons.info,
                                          color: _currentFollowers >=
                                                  _requiredFollowers
                                              ? Colors.green
                                              : Colors.orange,
                                          size: 30,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Follower Status: $_currentFollowers / $_requiredFollowers",
                                                style: TextStyle(
                                                    color: textColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              ValueListenableBuilder<bool>(
                                                valueListenable:
                                                    isMyanmarNotifier,
                                                builder:
                                                    (context, isMm, child) {
                                                  return Text(
                                                    _currentFollowers >=
                                                            _requiredFollowers
                                                        ? (isMm
                                                            ? "ဂုဏ်ယူပါတယ်! သင်သည် Monetization တောင်းဆိုရန် သတ်မှတ်ချက်ပြည့်မီပါသည်။"
                                                            : "Congratulations! You meet the requirements to apply for Monetization.")
                                                        : (isMm
                                                            ? "Monetization တောင်းဆိုရန် Follower 50k ပြည့်ရန် လိုအပ်နေသေးပါသည်။"
                                                            : "You need 50k followers to apply for Monetization."),
                                                    style: TextStyle(
                                                        color: textColor
                                                            .withOpacity(0.8),
                                                        fontSize: 13),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // 🚀 Follower 50k ပြည့်/မပြည့် အပေါ်မူတည်၍ Form ပြရန်
                                  if (_currentFollowers >=
                                      _requiredFollowers) ...[
                                    ValueListenableBuilder<bool>(
                                      valueListenable: isMyanmarNotifier,
                                      builder: (context, isMm, child) {
                                        return Text(
                                          isMm
                                              ? "Golden Mark ရှိပြီးဖြစ်ကာ လိုအပ်သော အချက်အလက်များ အောက်ပါအတိုင်း ဖြည့်သွင်းပါ -"
                                              : "You have a Golden Mark. Please fill in the required information below:",
                                          style: TextStyle(
                                              color:
                                                  textColor.withOpacity(0.7)),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // NRC Number
                                    ValueListenableBuilder<bool>(
                                      valueListenable: isMyanmarNotifier,
                                      builder: (context, isMm, child) {
                                        return _customTextField(
                                            _nrcController,
                                            isMm
                                                ? "NRC နံပါတ် (ဥပမာ - ၁၂/ဥကတ(နိုင်)၁၂၃၄၅၆)"
                                                : "NRC Number (e.g., 12/UgaTa(Naing)123456)",
                                            Icons.badge,
                                            textColor);
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // NRC Image Upload
                                    ValueListenableBuilder<bool>(
                                      valueListenable: isMyanmarNotifier,
                                      builder: (context, isMm, child) {
                                        return Text(
                                            isMm
                                                ? "မှတ်ပုံတင် (NRC) ပုံတင်ရန်"
                                                : "Upload NRC Image",
                                            style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold));
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: _pickImage,
                                      child: Container(
                                        height: 160,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Colors.white10
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color:
                                                  textColor.withOpacity(0.3)),
                                        ),
                                        child: _nrcImage == null
                                            ? Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.camera_alt,
                                                      size: 40,
                                                      color: textColor
                                                          .withOpacity(0.7)),
                                                  const SizedBox(height: 8),
                                                  ValueListenableBuilder<bool>(
                                                    valueListenable:
                                                        isMyanmarNotifier,
                                                    builder:
                                                        (context, isMm, child) {
                                                      return Text(
                                                          isMm
                                                              ? "ပုံရွေးချယ်ရန် နှိပ်ပါ"
                                                              : "Tap to select image",
                                                          style: TextStyle(
                                                              color: textColor
                                                                  .withOpacity(
                                                                      0.7)));
                                                    },
                                                  ),
                                                ],
                                              )
                                            : ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Image.file(_nrcImage!,
                                                    fit: BoxFit.cover),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Bank Account
                                    ValueListenableBuilder<bool>(
                                      valueListenable: isMyanmarNotifier,
                                      builder: (context, isMm, child) {
                                        return _customTextField(
                                            _bankController,
                                            isMm
                                                ? "ဘဏ်အကောင့် သို့မဟုတ် Wallet ID (KBZPay / AYA etc.)"
                                                : "Bank Account or Wallet ID (KBZPay / AYA etc.)",
                                            Icons.account_balance_wallet,
                                            textColor);
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // Policy Checkbox
                                    CheckboxListTile(
                                      title: ValueListenableBuilder<bool>(
                                        valueListenable: isMyanmarNotifier,
                                        builder: (context, isMm, child) {
                                          return Text(
                                            isMm
                                                ? "! မှတ်ပုံတင်နှင့် အကောင့်နံပါတ် or ဖုန်းနံပါတ် သေချာဖြည့်ပါ ပိုက်ဆံထုတ်လျှင် နံပါတ်မတူပါက ပြဿနာရှိသည်!\n*** အသက် ၁၈ နှစ်ပြည့်ပြီးဖြစ်ပြီး မူပိုင်ခွင့်စည်းကမ်းချက်များကို လိုက်နာမည်ဖြစ်ကြောင်း သဘောတူပါသည်။"
                                                : "! Please ensure your NRC and account/phone numbers are correct. Mismatches will cause issues during cash withdrawals!\n*** I confirm that I am at least 18 years old and agree to comply with copyright terms and conditions.",
                                            style: TextStyle(
                                                color: textColor, fontSize: 13),
                                          );
                                        },
                                      ),
                                      value: _isAgreed,
                                      activeColor: Colors.amber,
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (val) =>
                                          setState(() => _isAgreed = val!),
                                    ),
                                    const SizedBox(height: 25),

                                    // Submit Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : _submitRequest,
                                        child: ValueListenableBuilder<bool>(
                                          valueListenable: isMyanmarNotifier,
                                          builder: (context, isMm, child) {
                                            return Text(_isSubmitting
                                                ? (isMm
                                                    ? "တင်သွင်းနေသည်..."
                                                    : "Submitting...")
                                                : (isMm
                                                    ? "လျှောက်လွှာတင်မည်"
                                                    : "Submit Application"));
                                          },
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    // 50k မပြည့်သေးပါက ပြသမည့် ပုံစံ
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: ValueListenableBuilder<bool>(
                                          valueListenable: isMyanmarNotifier,
                                          builder: (context, isMm, child) {
                                            return Text(
                                              isMm
                                                  ? "Follower 50k ပြည့်မှသာ Monetization Request တင်နိုင်မည် ဖြစ်ပါသည်။"
                                                  : "You must reach 50k followers to submit a Monetization Request.",
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: textColor
                                                      .withOpacity(0.7),
                                                  fontSize: 14),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
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

  Widget _customTextField(TextEditingController controller, String label,
      IconData icon, Color textColor,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: textColor),
        enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: textColor.withOpacity(0.3))),
        focusedBorder:
            OutlineInputBorder(borderSide: BorderSide(color: textColor)),
      ),
    );
  }
}
