import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/widgets/banner_ad_widget.dart'; // 🌟 Banner Ad Widget ချိတ်ရန်
import 'package:intl/intl.dart';

class WithdrawHistoryPage extends StatelessWidget {
  const WithdrawHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();
    Color cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final User? user = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text("ငွေထုတ်ယူမှု မှတ်တမ်း",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('payment_requests')
                    .where('uid', isEqualTo: user?.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        "ငွေထုတ်ယူထားသည့် မှတ်တမ်း မရှိသေးပါ",
                        style: TextStyle(
                            color: textColor.withOpacity(0.7), fontSize: 16),
                      ),
                    );
                  }

                  var docs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;

                      String paymentMethod = data['paymentMethod'] ?? 'KBZPay';
                      num amount = data['amount'] ?? 0;
                      String status = data['status'] ?? 'pending';
                      String accountNumber = data['accountNumber'] ?? '';
                      String accountName = data['accountName'] ?? '';

                      Timestamp? timestamp = data['createdAt'] as Timestamp?;
                      String formattedDate = '';
                      if (timestamp != null) {
                        DateTime dateTime = timestamp.toDate();
                        formattedDate =
                            DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
                      }

                      Color statusColor = Colors.orange;
                      String statusText = 'စစ်ဆေးဆဲ (Pending)';
                      if (status == 'approved') {
                        statusColor = Colors.green;
                        statusText = 'ပြီးမြောက်သည် (Approved)';
                      } else if (status == 'rejected') {
                        statusColor = Colors.red;
                        statusText = 'ပယ်ချသည် (Rejected)';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(isDark ? 0.7 : 0.95),
                          borderRadius: BorderRadius.circular(12),
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
                                  "$amount MMK",
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("အမည်: $accountName",
                                    style: TextStyle(
                                        color: textColor.withOpacity(0.8),
                                        fontSize: 13)),
                                Text("နံပါတ်: $accountNumber",
                                    style: TextStyle(
                                        color: textColor.withOpacity(0.8),
                                        fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(formattedDate,
                                    style: TextStyle(
                                        color: textColor.withOpacity(0.5),
                                        fontSize: 11)),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const BannerAdWidget(), // 🌟 အောက်ဆုံးတွင် Banner Ad ထည့်သွင်းခြင်း
          ],
        ),
      ),
    );
  }
}
