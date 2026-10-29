// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:karma/utilis/navigation_helper.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/services/r2_service.dart';
import 'package:karma/widgets/banner_ad_widget.dart';

class GoldenVerifiedPage extends StatefulWidget {
  const GoldenVerifiedPage({super.key});

  @override
  State<GoldenVerifiedPage> createState() => _GoldenVerifiedPageState();
}

class _GoldenVerifiedPageState extends State<GoldenVerifiedPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _paymentIdController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();

  String _selectedMethod = 'KBZPay'; // 🌟 ငွေပေးချေသည့် နည်းလမ်းအတွက် Default
  File? _screenshotImage; // 🌟 Pay Slip ပုံအတွက် File
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _reasonController.dispose();
    _paymentIdController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  // 🖼️ ငွေလွှဲ Screenshot ပုံရွေးချယ်ရန်
  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _screenshotImage = File(pickedFile.path));
    }
  }

  // 🌟 Dialog ဖန်းရှင်း
  void _showGoldenBenefitsDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool isDarkMode = (themeProvider.currentTheme != 'Default');
    Color dialogTextColor = isDarkMode ? Colors.white : Colors.black87;

    Color dialogBgColor = isDarkMode
        ? Colors.black.withOpacity(0.4)
        : Colors.white.withOpacity(0.5);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dialogBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dialogTextColor.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.amber, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        "Golden Mark အခွင့်အရေးများ",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: dialogTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        _BenefitItem(
                          icon: Icons.palette,
                          title: "Theme များပြောင်းလဲခြင်း",
                          description:
                              "Theme များကို ၃ မျိုးထက်ပို၍ လွတ်လပ်စွာ ပြောင်းလဲအသုံးပြုနိုင်ခြင်း။",
                          textColor: dialogTextColor,
                        ),
                        const SizedBox(height: 12),
                        _BenefitItem(
                          icon: Icons.trending_up,
                          title: "For You Page တွင် ဦးစားပေးခြင်း",
                          description:
                              "For You Page တွင် အခြားသူများထက် မိမိ၏ Post သည် ပိုမိုနေရာရရှိပြီး Visibility ပိုကောင်းခြင်း။",
                          textColor: dialogTextColor,
                        ),
                        const SizedBox(height: 12),
                        _BenefitItem(
                          icon: Icons.monetization_on,
                          title: "Monetization လျှောက်ထားနိုင်ခြင်း",
                          description:
                              "Monetization လျှောက်ထားရာတွင်မဖြစ်မနေ (Follower 50K ) လိုအပ်ပါသည်။",
                          textColor: dialogTextColor,
                        ),
                        const SizedBox(height: 12),
                        _BenefitItem(
                          icon: Icons.account_balance_wallet,
                          title: "ငွေထုတ်ယူမှု အခွင့်အရေး",
                          description:
                              "Earn & Reward မှ သတ်မှတ်ထားသည့်အတိုင်း တစ်လလျှင် ၃ ကြိမ်အထိ ငွေထုတ်ယူနိုင်ခြင်း။",
                          textColor: dialogTextColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("ပိတ်မည်",
                          style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold)),
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

  Future<void> _submitRequest() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _reasonController.text.trim().isEmpty ||
        _paymentIdController.text.trim().isEmpty ||
        _accountNameController.text.trim().isEmpty ||
        _screenshotImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "ကျေးဇူးပြု၍ အချက်အလက် အားလုံးနှင့် ငွေလွှဲပုံ (Screenshot) ကိုပါ ဖြည့်သွင်းပါ။")),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (user == null) return;

      // ☁️ R2 သို့ Screenshot ပုံတင်ပြီး URL ရယူခြင်း
      String? screenshotUrl = await R2Service.uploadFile(
          _screenshotImage!, 'verification_requests');

      if (screenshotUrl == null) {
        throw Exception(
            "ငွေလွှဲပုံ (Screenshot) ကို တင်၍မရပါ။ ဆက်သွယ်မှုကို စစ်ဆေးပါ။");
      }

      // 📦 Firestore ထဲသို့ verification_requests ဖြင့် အချက်အလက်များ သိမ်းဆည်းခြင်း
      await FirebaseFirestore.instance.collection('verification_requests').add({
        'uid': user!.uid,
        'displayName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'reason': _reasonController.text.trim(),
        'paymentMethod':
            _selectedMethod, // 🌟 ရွေးချယ်ထားသော Payment Method ထည့်သွင်းခြင်း
        'paymentTransactionId': _paymentIdController.text.trim(),
        'paymentAccountName': _accountNameController.text.trim(),
        'screenshotUrl': screenshotUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'role': 'pending'});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "လျှောက်လွှာနှင့် ငွေပေးချေမှု အချက်အလက် ပို့ပြီးပါပြီ။ Admin စစ်ဆေးမှုကို စောင့်ဆိုင်းပါ။")),
      );
      NavigationHelper.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("အမှားအယွင်း ရှိနေပါသည်: $e")),
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
          title: Text("Golden Mark လျှောက်ထားရန်",
              style: TextStyle(color: textColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          actions: [
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              color: isDarkMode
                  ? Colors.black.withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: textColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              onSelected: (value) {
                if (value == 'benefits') {
                  _showGoldenBenefitsDialog();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'benefits',
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text("Golden Mark အခွင့်အရေးများ",
                          style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('verification_requests')
                    .where('uid', isEqualTo: user?.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  String status = '';
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    var latestDoc = snapshot.data!.docs.first;
                    var data = latestDoc.data() as Map<String, dynamic>;
                    status = data['status'] ?? '';
                  }

                  if (status == 'approved') {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified,
                                color: Colors.amber, size: 80),
                            const SizedBox(height: 20),
                            Text("Golden Mark အောင်မြင်ထားပါသည်",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            Text(
                                "သင်သည် Karma App ၏ Verified Golden User တစ်ဦး ဖြစ်ပါသည်၊ အထူးအခွင့်အရေးများကို လွတ်လပ်စွာ အသုံးပြုနိုင်ပါပြီ။",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: textColor.withOpacity(0.7)),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }

                  if (status == 'pending') {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: _buildStatusCard(
                          "စစ်ဆေးဆဲ (Pending)",
                          "သင့်၏ Golden Mark လျှောက်လွှာနှင့် ငွေလွှဲအချက်အလက်များကို Admin မှ စစ်ဆေးနေဆဲ ဖြစ်ပါသည်။ ကျေးဇူးပြု၍ ခဏစောင့်ဆိုင်းပေးပါ။",
                          Colors.orange,
                          textColor,
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (status == 'rejected') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: const Text(
                              "သင့်၏ ယခင်လျှောက်လွှာမှာ ငြင်းပယ်ခံခဲ့ရပါသည်။ အချက်အလက်များကို သေချာစိစစ်ပြီး ပြန်လည်လျှောက်ထားနိုင်ပါသည်။",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        Text(
                            "Verified Golden Mark ရရှိရန် အချက်အလက်များဖြည့်ပါ",
                            style:
                                TextStyle(color: textColor.withOpacity(0.7))),
                        const SizedBox(height: 20),
                        _customTextField(_nameController, "အကောင့်နာမည်",
                            Icons.person, textColor),
                        const SizedBox(height: 15),
                        _customTextField(_emailController, "အကောင့် Email",
                            Icons.email, textColor),
                        const SizedBox(height: 15),
                        _customTextField(_reasonController, "အကြောင်းပြချက်",
                            Icons.note, textColor,
                            maxLines: 3),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white10
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "50000 ၁လစာ\n"
                            "KBZPay: 09-790543386 (Naung Naung Zaw)\n"
                            "WavePay: 09-790543386 (Naung Naung Zaw)\n"
                            "AYA Pay: 09-790543386 (Naung Naung Zaw)\n\n"
                            "ငွေလွှဲရာတွင် Karma App ၏ တရားဝင်ကိုယ်စားလှယ် (Naung Naung Zaw) ထံသို့ လွှဲပေးရန်။",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 15),

                        // 🌟 Payment Method Dropdown (KBZPay, WavePay, AYA Pay)[cite: 2]
                        DropdownButtonFormField<String>(
                          value: _selectedMethod,
                          dropdownColor:
                              isDarkMode ? Colors.grey[900] : Colors.white,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: "ငွေပေးချေသည့် နည်းလမ်း",
                            labelStyle:
                                TextStyle(color: textColor.withOpacity(0.7)),
                            prefixIcon: Icon(Icons.payment, color: textColor),
                            enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: textColor.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: textColor)),
                          ),
                          items: ['KBZPay', 'WavePay', 'AYA Pay']
                              .map((method) => DropdownMenuItem(
                                  value: method, child: Text(method)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedMethod = val!),
                        ),
                        const SizedBox(height: 15),

                        _customTextField(_paymentIdController, "Transaction ID",
                            Icons.receipt, textColor),
                        const SizedBox(height: 15),
                        _customTextField(_accountNameController, "Sender Name",
                            Icons.account_box, textColor),
                        const SizedBox(height: 20),

                        // 📸 Pay Slip Screenshot Upload Section
                        Text("ငွေလွှဲပြီးကြောင်း Screenshot ပုံတင်ရန်",
                            style: TextStyle(
                                color: textColor, fontWeight: FontWeight.bold)),
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
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: textColor.withOpacity(0.3)),
                            ),
                            child: _screenshotImage == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt,
                                          size: 40,
                                          color: textColor.withOpacity(0.7)),
                                      const SizedBox(height: 8),
                                      Text("Screenshot ပုံရွေးချယ်ရန် နှိပ်ပါ",
                                          style: TextStyle(
                                              color:
                                                  textColor.withOpacity(0.7))),
                                    ],
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(_screenshotImage!,
                                        fit: BoxFit.cover),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitRequest,
                            child: Text(_isSubmitting
                                ? "လုပ်ဆောင်နေသည်..."
                                : "လျှောက်လွှာတင်မည်"),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      String title, String message, Color statusColor, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_top, size: 40, color: statusColor),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.4)),
        ],
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

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color textColor;

  const _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.amber, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
