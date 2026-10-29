import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:karma/main.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/widgets/banner_ad_widget.dart';

class IncomeAnalysisPage extends StatelessWidget {
  const IncomeAnalysisPage({super.key});

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
          title: ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return Text(
                isMm ? "ဝင်ငွေ စာရင်းချုပ်" : "Earnings Summary",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              );
            },
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
            double currentBalance = (userData['balance'] ?? 0).toDouble();

            // 🌟 ဤနေရာတွင် User ၏ Monetization Status ကို စစ်ဆေးခြင်း
            bool isApproved = (userData['monetizationStatus'] == 'approved');

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('uid', isEqualTo: user?.uid)
                  .snapshots(),
              builder: (context, postSnapshot) {
                if (!postSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                double totalTipIncome = 0;
                double totalMonetizationIncome = 0;

                for (var doc in postSnapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  double pTips = (data['totalTips'] ?? 0.0).toDouble();

                  // 🌟 Approved ဖြစ်မှသာ Like နှင့် Comment များကို ဝင်ငွေအဖြစ် တွက်မည်
                  double pMonetization = isApproved
                      ? (((data['likesCount'] ?? 0) * 5.0) +
                          ((data['commentsCount'] ?? 0) * 3.0))
                      : 0.0;

                  totalTipIncome += pTips;
                  totalMonetizationIncome += pMonetization;
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          _buildHeaderCards(
                              context,
                              currentBalance,
                              totalTipIncome,
                              totalMonetizationIncome,
                              textColor),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ValueListenableBuilder<bool>(
                                valueListenable: isMyanmarNotifier,
                                builder: (context, isMm, child) {
                                  return Text(
                                    isMm
                                        ? "Post အလိုက် ဝင်ငွေများ"
                                        : "Earnings by Post",
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            itemCount: postSnapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              var data = postSnapshot.data!.docs[index].data()
                                  as Map<String, dynamic>;
                              double pTips =
                                  (data['totalTips'] ?? 0.0).toDouble();

                              // 🌟 Post တစ်ခုချင်းစီအတွက်လည်း Status အပေါ်မူတည်ပြီး တွက်မည်
                              double pMonetization = isApproved
                                  ? (((data['likesCount'] ?? 0) * 5.0) +
                                      ((data['commentsCount'] ?? 0) * 3.0))
                                  : 0.0;
                              double pTotal = pTips + pMonetization;

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      cardColor.withOpacity(isDark ? 0.6 : 0.9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      data['mediaUrl'] ?? '',
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  title: Text(
                                    data['text'] ?? 'Post',
                                    style: TextStyle(color: textColor),
                                    maxLines: 1,
                                  ),
                                  subtitle: Text(
                                    "❤️ ${data['likesCount']}  💬 ${data['commentsCount']}  🔥 ${data['totalTips'] ?? 0} K-Points",
                                    style: TextStyle(
                                        color: textColor.withOpacity(0.6)),
                                  ),
                                  trailing: Text(
                                    "+ $pTotal K-Points",
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const BannerAdWidget(),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showTipInfoDialog(BuildContext context, Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: ValueListenableBuilder<bool>(
          valueListenable: isMyanmarNotifier,
          builder: (context, isMm, child) {
            return Text(
              isMm ? "🔥 Tip မှ ရရှိငွေ အကြောင်း" : "🔥 About Tip Earnings",
              style: const TextStyle(fontWeight: FontWeight.bold),
            );
          },
        ),
        content: SingleChildScrollView(
          child: ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return Text(
                isMm
                    ? "• Tip ရချိန်တွင် သင်၏ (သင့်လက်ရှိ စုစုပေါင်းလက်ကျန်ငွေ) ထဲသို့ ချက်ချင်း ရောက်ရှိသွားမည် ဖြစ်ပါသည်။\n\n"
                        "• ယခု Tip မှ ရရှိငွေသည် သင်၏ Post များမှတစ်ဆင့် လက်ခံရရှိထားသော စုစုပေါင်း Tip ပမာဏ (Lifetime Received Tips) ဖြစ်ပြီး သင်၏ တစ်သက်တာ မှတ်တမ်း သက်သက်သာ ဖြစ်ပါသည်။\n\n"
                        "• အကယ်၍ သင်သည် အခြားသူ၏ Post သို့ Tip ပြန်လည်ပေးအပ်ခဲ့ပါက သင့်လက်ရှိ စုစုပေါင်းလက်ကျန်ငွေမှ နုတ်ယူသွားမည်ဖြစ်ပြီး၊ ဤ Tip မှရရှိသော စုစုပေါင်းငွေစာရင်းမှာမူ မူလအတိုင်း ဆက်လက် တည်ရှိနေမည် ဖြစ်ပါသည်။\n\n"
                        "• သင့် Post တစ်ခုချင်းစီအောက်တွင်လည်း ဤကဲ့သို့ပင် မှတ်တမ်းတင်ထားမည် ဖြစ်ပါသည်။"
                    : "• When you receive a tip, it will be instantly added to your current total balance.\n\n"
                        "• The tip earnings shown here represent the total lifetime tips received through your posts and serve as a lifetime record.\n\n"
                        "• If you send a tip to someone else's post, it will be deducted from your current balance, but your lifetime received tips record will remain unaffected.\n\n"
                        "• This will also be recorded similarly under each of your individual posts.",
                style: const TextStyle(fontSize: 14, height: 1.5),
              );
            },
          ),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  isMm ? "နားလည်ပါပြီ" : "Got it",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String amount, Color color,
      {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap, // 🌟 နှိပ်လိုက်ရင် အလုပ်လုပ်ရန်
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.center),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.info_outline,
                        size: 14,
                        color: Colors
                            .white70), // 🌟 သေးငယ်တဲ့ info သင်္ကေတလေး ထည့်ပေးခြင်း
                  ]
                ],
              ),
              const SizedBox(height: 5),
              Text(amount,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCards(BuildContext context, double balance,
      double tipIncome, double monetizationIncome, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blueAccent, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: isMyanmarNotifier,
                  builder: (context, isMm, child) {
                    return Text(
                      isMm
                          ? "လက်ရှိ စုစုပေါင်းလက်ကျန်ငွေ"
                          : "Current Total Balance",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    );
                  },
                ),
                const SizedBox(height: 5),
                Text("$balance K-Points",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: isMyanmarNotifier,
                builder: (context, isMm, child) {
                  return _buildInfoCard(
                    isMm ? "Tip မှ ရရှိငွေ" : "Tip Earnings",
                    "$tipIncome K-Points",
                    Colors.deepOrange,
                    onTap: () => _showTipInfoDialog(context, textColor),
                  );
                },
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<bool>(
                valueListenable: isMyanmarNotifier,
                builder: (context, isMm, child) {
                  return _buildInfoCard(
                    isMm
                        ? "Monetization (Like/Cmt)"
                        : "Monetization (Like/Cmt)",
                    "$monetizationIncome K-Points",
                    Colors.green,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
