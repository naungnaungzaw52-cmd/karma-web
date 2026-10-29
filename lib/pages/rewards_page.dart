// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:karma/main.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// 🌟 AdMob Reward Helper Class (Daily Limit နှင့် Loading State ပါဝင်သည်)
class AdMobRewardHelper {
  RewardedAd? _rewardedAd;
  bool _isLoaded = false;
  final VoidCallback? onAdStateChanged;

  AdMobRewardHelper({this.onAdStateChanged});

  bool get isLoaded => _isLoaded;

  // Rewarded Ad ကို Load လုပ်ရန်
  void loadRewardedAd() {
    _isLoaded = false;
    onAdStateChanged?.call();

    RewardedAd.load(
      adUnitId:
          'ca-app-pub-8755843731256088/9385854201', // Test Ad ID (production မှာ ကိုယ့် ID နဲ့လဲရန်)
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _isLoaded = true;
          onAdStateChanged
              ?.call(); // Ad loaded ဖြစ်လာပါက UI ကို ချက်ချင်း update လုပ်ရန်
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _isLoaded = false;
          onAdStateChanged?.call();
        },
      ),
    );
  }

  // Ad ပြသရန်နှင့် Daily Limit စစ်ဆေးပြီး ဆုလာဘ် (Reward) ပေးရန်
  void showRewardedAd(BuildContext context, double rewardAmount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      // ၁။ Firestore ကနေ User ရဲ့ ယနေ့ ကြော်ငြာကြည့်ရှုမှု အချက်အလက်များကို ယူမည်
      DocumentSnapshot userSnapshot = await userRef.get();
      if (!userSnapshot.exists) return;

      var userData = userSnapshot.data() as Map<String, dynamic>;

      // ရက်စွဲအဟောင်းဖြစ်နေရင် (ရက်သစ်ပြောင်းသွားရင်) အရေအတွက်ကို 0 ပြန်စရန်
      String todayStr = DateTime.now()
          .toIso8601String()
          .substring(0, 10); // ပုံစံ - YYYY-MM-DD
      String lastWatchDate = userData['lastAdWatchDate'] ?? '';
      int watchCount = userData['adWatchCount'] ?? 0;

      if (lastWatchDate != todayStr) {
        watchCount = 0; // ရက်သစ်ဖြစ်သွားပါက 0 ပြန်စမည်
      }

      // ၂။ Daily Limit (တစ်နေ့လျှင် အများဆုံး ၂၀ ကြိမ်) စစ်ဆေးခြင်း
      if (watchCount >= 30) {
        bool isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? "ယနေ့အတွက် ကြော်ငြာကြည့်ရှုနိုင်သည့် ကန့်သတ်ချက် (၃၀ ကြိမ်) ပြည့်သွားပါပြီ။ မနက်ဖြန်မှ ထပ်ကြိုးစားပေးပါ။"
                  : "Daily ad viewing limit (30 times) reached for today. Please try again tomorrow.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ၃။ ကြော်ငြာ အသင့်ဖြစ်မဖြစ် စစ်ဆေးပြီး ပြသခြင်း
      if (_isLoaded && _rewardedAd != null) {
        _rewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
            // ကြော်ငြာအဆုံးထိ ကြည့်ပြီးပါက Balance တိုးမည် & Count တိုးမည်
            await FirebaseFirestore.instance
                .runTransaction((transaction) async {
              DocumentSnapshot snapshot = await transaction.get(userRef);
              if (snapshot.exists) {
                var freshData = snapshot.data() as Map<String, dynamic>;
                double currentBalance =
                    (freshData['balance'] ?? 0.0).toDouble();

                String dbLastDate = freshData['lastAdWatchDate'] ?? '';
                int dbCount = (dbLastDate == todayStr)
                    ? (freshData['adWatchCount'] ?? 0)
                    : 0;
                int updatedCount = dbCount + 1;

                transaction.update(userRef, {
                  'balance': currentBalance + rewardAmount,
                  'adWatchCount': updatedCount,
                  'lastAdWatchDate': todayStr,
                });
              }
            });

            bool isMm = isMyanmarNotifier.value;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isMm
                      ? "ဂုဏ်ယူပါတယ်! K-Points $rewardAmount ရရှိသွားပါပြီ။ (${watchCount + 1}/30)"
                      : "Congratulations! You have received $rewardAmount K-Points. (${watchCount + 1}/30)",
                ),
              ),
            );
          },
        );
        _rewardedAd = null;
        _isLoaded = false;
        loadRewardedAd(); // နောက်တစ်ကြိမ်အတွက် ထပ် load ထားမည်
      } else {
        bool isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? "ကြော်ငြာ မရှိသေးပါ၊ ခဏစောင့်ပေးပါ။"
                  : "No ads available yet, please wait a moment.",
            ),
          ),
        );
        loadRewardedAd();
      }
    } catch (e) {
      print("Ad Error: $e");
    }
  }
}

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  late final AdMobRewardHelper _rewardHelper;

  @override
  void initState() {
    super.initState();
    // Ad State ပြောင်းလဲတိုင်း UI ချက်ချင်း Rebuild ဖြစ်စေရန် Callback ထည့်သွင်းခြင်း
    _rewardHelper = AdMobRewardHelper(
      onAdStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    _rewardHelper.loadRewardedAd(); // Page စဖွင့်ချင်း Ad ကို load လုပ်ထားမည်
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();
    Color cardColor = isDark ? Colors.grey[900]! : Colors.white;

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            "Win-Win Ad Reward",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          iconTheme: IconThemeData(color: textColor),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            double balance = (userData['balance'] ?? 0.0).toDouble();

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // 🌟 Balance Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blueAccent, Colors.purpleAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable: isMyanmarNotifier,
                              builder: (context, isMm, child) {
                                return Text(
                                  isMm
                                      ? "လက်ရှိစုဆောင်းရရှိငွေ"
                                      : "Current Balance",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "$balance K-Points",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 🌟 Watch Ad to Earn Section
                      ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Text(
                            isMm
                                ? "ကြော်ငြာကြည့်ပြီး ငွေရှာရန်"
                                : "Watch Ads to Earn",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(isDark ? 0.7 : 0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.slow_motion_video,
                                    color: Colors.blueAccent, size: 36),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ValueListenableBuilder<bool>(
                                        valueListenable: isMyanmarNotifier,
                                        builder: (context, isMm, child) {
                                          return Text(
                                            isMm
                                                ? "Rewarded Ad ကြည့်မည်"
                                                : "Watch Rewarded Ad",
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                      ValueListenableBuilder<bool>(
                                        valueListenable: isMyanmarNotifier,
                                        builder: (context, isMm, child) {
                                          return Text(
                                            isMm
                                                ? "ဗီဒီယိုကြော်ငြာ တစ်ခုကြည့်ရုံဖြင့် K-Points 20 ရယူပါ။ (တစ်နေ့ ၃၀ ကြိမ်)"
                                                : "Watch a video ad to earn 20 K-Points. (30 times daily)",
                                            style: TextStyle(
                                              color: textColor.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  // Ad မလာသေးရင် မီးခိုးရောင်၊ လာပြီးရင် အပြာရောင်ပြမည်
                                  backgroundColor: _rewardHelper.isLoaded
                                      ? Colors.blueAccent
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                // Ad မလာသေးရင် နှိပ်၍မရအောင် ပိတ်ထားမည် (onPressed: null)
                                onPressed: _rewardHelper.isLoaded
                                    ? () {
                                        _rewardHelper.showRewardedAd(
                                            context, 20.0);
                                      }
                                    : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (!_rewardHelper.isLoaded) ...[
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    ValueListenableBuilder<bool>(
                                      valueListenable: isMyanmarNotifier,
                                      builder: (context, isMm, child) {
                                        return Text(
                                          _rewardHelper.isLoaded
                                              ? (isMm
                                                  ? "ကြော်ငြာစတင်ကြည့်မည်"
                                                  : "Watch Ad")
                                              : (isMm
                                                  ? "ကြော်ငြာ ဆွဲနေသည် ခဏစောင့်ပါ..."
                                                  : "Loading Ad, please wait..."),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const BannerAdWidget(),
              ],
            );
          },
        ),
      ),
    );
  }
}
