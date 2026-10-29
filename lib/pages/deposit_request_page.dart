// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:karma/utilis/navigation_helper.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/services/r2_service.dart';
import 'package:karma/widgets/banner_ad_widget.dart';

class DepositRequestPage extends StatefulWidget {
  const DepositRequestPage({super.key});

  @override
  State<DepositRequestPage> createState() => _DepositRequestPageState();
}

class _DepositRequestPageState extends State<DepositRequestPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionIdController =
      TextEditingController();
  final TextEditingController _senderNameController = TextEditingController();

  String _selectedMethod = 'KBZPay';
  File? _screenshotImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    _senderNameController.dispose();
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

  // 🚀 ငွေသွင်းရန် တောင်းဆိုချက်ကို တင်သွင်းခြင်း
  Future<void> _submitDeposit() async {
    if (_amountController.text.trim().isEmpty ||
        _transactionIdController.text.trim().isEmpty ||
        _senderNameController.text.trim().isEmpty ||
        _screenshotImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "ကျေးဇူးပြု၍ ငွေပမာဏ၊ Transaction ID၊ Sender Name နှင့် ငွေလွှဲပုံ (Screenshot) အားလုံး ဖြည့်သွင်းပါ။"),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (user == null) return;

      // ☁️ R2 သို့ Screenshot ပုံပို့ပြီး URL ရယူခြင်း[cite: 7]
      String? screenshotUrl =
          await R2Service.uploadFile(_screenshotImage!, 'deposit_requests');

      if (screenshotUrl == null) {
        throw Exception(
            "ငွေလွှဲပုံ (Screenshot) ကို R2 သို့ တင်၍မရပါ။ ဆက်သွယ်မှုကို စစ်ဆေးပါ။");
      }

      // 📦 Firestore ထဲသို့ deposit_requests collection ဖြင့် အချက်အလက်များ သိမ်းဆည်းခြင်း[cite: 7]
      await FirebaseFirestore.instance.collection('deposit_requests').add({
        'uid': user!.uid,
        'email': user!.email ?? '',
        'amount': num.parse(_amountController.text.trim()),
        'method': _selectedMethod,
        'transactionId': _transactionIdController.text.trim(),
        'senderName': _senderNameController.text.trim(),
        'screenshotUrl': screenshotUrl,
        'status': 'pending', // 'pending', 'approved', 'rejected'[cite: 7]
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "ငွေသွင်းရန် တောင်းဆိုလွှာ ပို့ပြီးပါပြီ။ Admin အတည်ပြုမှုကို စောင့်ဆိုင်းပါ။")),
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
          title: Text("အကောင့်ထဲငွေသွင်းရန် (Deposit)",
              style: TextStyle(color: textColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // 🌟 User တင်ထားသော deposit_requests များကို စစ်ဆေးရန် Query ဆွဲခြင်း
                stream: FirebaseFirestore.instance
                    .collection('deposit_requests')
                    .where('uid', isEqualTo: user?.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  bool canSubmitNew = true;
                  Widget? activeStatusWidget;

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    var latestDoc = snapshot.data!.docs.first;
                    var data = latestDoc.data() as Map<String, dynamic>;
                    String status = data['status'] ?? 'pending';
                    num amount = data['amount'] ?? 0;
                    Timestamp? createdAt = data['createdAt'] as Timestamp?;

                    if (status == 'pending') {
                      canSubmitNew = false;
                      activeStatusWidget = _buildStatusCard(
                        "စစ်ဆေးဆဲ (Pending)",
                        "သင့်ငွေသွင်းတောင်းဆိုမှု ($amount MMK) ကို Admin မှ စစ်ဆေးနေဆဲ ဖြစ်ပါသည်။ ကျေးဇူးပြု၍ စောင့်ဆိုင်းပေးပါ။",
                        Colors.orange,
                        textColor,
                      );
                    } else if (status == 'approved' && createdAt != null) {
                      DateTime requestDate = createdAt.toDate();
                      DateTime now = DateTime.now();
                      // Approved ဖြစ်ပြီး တစ်ရက် (၂၄ နာရီ) မပြည့်သေးပါက ထပ်မတင်ခိုင်းသေးပါ
                      if (now.difference(requestDate).inHours < 24) {
                        canSubmitNew = false;
                        activeStatusWidget = _buildStatusCard(
                          "အတည်ပြုပြီး (Approved)",
                          "သင့်ငွေသွင်းမှု ($amount MMK) အောင်မြင်ထားပါသည်။ နောက်တစ်ရက်မှသာ ထပ်မံငွေသွင်းနိုင်မည် ဖြစ်ပါသည်။",
                          Colors.green,
                          textColor,
                        );
                      }
                    }
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 📢 ငွေလွှဲရမယ့် Admin အကောင့်အချက်အလက်ပြ Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white10
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.amber, size: 20),
                                  const SizedBox(width: 8),
                                  Text("ငွေလွှဲရန် ငွေစာရင်းအချက်အလက်များ",
                                      style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "50000 ၁လစာ\n"
                                "KBZPay: 09-790543386 (Naung Naung Zaw)\n"
                                "WavePay: 09-790543386 (Naung Naung Zaw)\n"
                                "AYA Pay: 09-790543386 (Naung Naung Zaw)\n\n"
                                "ငွေလွှဲရာတွင် Karma App ၏ တရားဝင်ကိုယ်စားလှယ် (Naung Naung Zaw) ထံသို့ လွှဲပေးရန်။",
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 🌟 Pending သို့မဟုတ် Approved ဖြစ်နေပါက Form အစား Status Card ကို ပြမည်
                        if (!canSubmitNew && activeStatusWidget != null) ...[
                          activeStatusWidget,
                        ] else ...[
                          // Payment Method Dropdown
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

                          // Amount Controller
                          _customTextField(_amountController,
                              "လွှဲငွေပမာဏ (MMK)", Icons.money, textColor,
                              keyboardType: TextInputType.number),
                          const SizedBox(height: 15),

                          // Transaction ID Controller
                          _customTextField(
                              _transactionIdController,
                              "Transaction ID (သို့) ငွေလွှဲနံပါတ်",
                              Icons.receipt,
                              textColor),
                          const SizedBox(height: 15),

                          // Sender Name Controller
                          _customTextField(
                              _senderNameController,
                              "လွှဲပေးသည့်အမည် (Sender Name)",
                              Icons.person,
                              textColor),
                          const SizedBox(height: 20),

                          // 📸 Screenshot Upload Section
                          Text("ငွေလွှဲပြီးကြောင်း Screenshot ပုံတင်ရန်",
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold)),
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
                                border: Border.all(
                                    color: textColor.withOpacity(0.3)),
                              ),
                              child: _screenshotImage == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt,
                                            size: 40,
                                            color: textColor.withOpacity(0.7)),
                                        const SizedBox(height: 8),
                                        Text(
                                            "Screenshot ပုံရွေးချယ်ရန် နှိပ်ပါ",
                                            style: TextStyle(
                                                color: textColor
                                                    .withOpacity(0.7))),
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

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black87,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _isSubmitting ? null : _submitDeposit,
                              child: Text(
                                _isSubmitting
                                    ? "တင်သွင်းနေသည်..."
                                    : "ငွေသွင်းရန် တောင်းဆိုမည်",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
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

  // 🌟 Status ပြသရန် သီးသန့် Card ပုံစံ
  Widget _buildStatusCard(
      String title, String message, Color statusColor, Color textColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Column(
        children: [
          Icon(Icons.hourglass_top, size: 40, color: statusColor),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _customTextField(TextEditingController controller, String label,
      IconData icon, Color textColor,
      {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
