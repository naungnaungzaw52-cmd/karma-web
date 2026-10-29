// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:ui'; // 🌟 BackdropFilter အတွက် လိုအပ်သည်
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:karma/main.dart';
import 'package:karma/pages/golden_verified_page.dart';
import 'package:karma/pages/monetization_request.dart';
import 'package:karma/pages/earn_and_reward_page.dart';
import 'package:karma/services/help_page.dart';
import 'package:karma/services/delete_account.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/utilis/navigation_helper.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_dashboard_page.dart';

class SettingsPage extends StatelessWidget {
  final bool isMm;
  final ValueNotifier<bool> isMyanmarNotifier;
  final Function(BuildContext, bool, String?) showThemeSelectionDialog;

  const SettingsPage({
    super.key,
    required this.isMm,
    required this.isMyanmarNotifier,
    required this.showThemeSelectionDialog,
  });

  // 🌟 Google Drive Link များ သို့မဟုတ် Web Link များကို ဖွင့်ပေးမည့် Helper Function
  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Link ကို ဖွင့်၍မရပါ: $urlString")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // 🌟 အကောင့်ထွက်ရန် (Log Out) လုပ်ဆောင်ချက်
  Future<void> _signOut(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pop();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MyApp()),
        (Route<dynamic> route) => false,
      );
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("အကောင့်ထွက်ရာတွင် အမှားအယွင်းရှိပါသည်: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🚫 Blocked Users List စာမျက်နှာသို့ သွားရန်
  void _openBlockedUsersPage(BuildContext context, String currentUid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlockedUsersPage(currentUid: currentUid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const String termsOfServiceUrl =
        'https://naungnaungzaw52-cmd.github.io/karma-policies/terms.html';
    const String privacyPolicyUrl =
        'https://naungnaungzaw52-cmd.github.io/karma-policies/privacy.html';

    return ValueListenableBuilder<bool>(
      valueListenable: isMyanmarNotifier,
      builder: (context, currentIsMm, child) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final User? user = FirebaseAuth.instance.currentUser;

        bool isDark = (themeProvider.currentTheme != 'Default');
        Color textColor = themeProvider.getTextColor();

        Color boxBgColor = isDark
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.4);

        return Container(
          decoration: themeProvider.getBackgroundDecoration(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              title: Text(
                currentIsMm ? "ဆက်တင်များ" : "Settings",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: user == null
                      ? const Center(child: Text("Please login"))
                      : FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            bool isAdminOrMember = false;
                            String userRole = '';
                            if (snapshot.hasData && snapshot.data!.exists) {
                              var userData = snapshot.data!.data()
                                  as Map<String, dynamic>?;

                              if (userData != null) {
                                userRole = userData['role'] ?? '';
                                if (userRole == 'admin' ||
                                    userRole == 'team_karma') {
                                  isAdminOrMember = true;
                                }
                              }
                            }

                            return ListView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              children: [
                                // --- Admin Control ---
                                if (isAdminOrMember) ...[
                                  _buildSectionHeader("Admin Control", isDark),
                                  _buildBlurCard(
                                    boxBgColor: boxBgColor,
                                    child: ListTile(
                                      dense: true,
                                      leading: const Icon(
                                          Icons.admin_panel_settings,
                                          color: Colors.redAccent),
                                      title: Text(
                                        currentIsMm
                                            ? "Admin Dashboard ဝင်ရန်"
                                            : "Admin Dashboard",
                                        style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      trailing: Icon(Icons.arrow_forward_ios,
                                          size: 14, color: textColor),
                                      onTap: () {
                                        NavigationHelper.push(
                                            context,
                                            AdminDashboardPage(
                                              userRole: userRole,
                                            ));
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // --- Section 1: Monetization & Rewards ---
                                _buildSectionHeader(
                                    currentIsMm
                                        ? "ဝင်ငွေနှင့် ဆုလာဘ်များ"
                                        : "Monetization & Rewards",
                                    isDark),
                                _buildBlurCard(
                                  boxBgColor: boxBgColor,
                                  child: Column(
                                    children: [
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.verified,
                                            color: Colors.amber),
                                        title: Text(
                                          currentIsMm
                                              ? "Golden Mark လျှောက်ထားရန်"
                                              : "Request Golden Mark",
                                          style: TextStyle(color: textColor),
                                        ),
                                        trailing: Icon(Icons.arrow_forward_ios,
                                            size: 14, color: textColor),
                                        onTap: () => NavigationHelper.push(
                                            context,
                                            const GoldenVerifiedPage()),
                                      ),
                                      _buildDivider(isDark),
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(
                                            Icons.monetization_on,
                                            color: Colors.green),
                                        title: Text(
                                          currentIsMm
                                              ? "Monetization လျှောက်ထားရန်"
                                              : "Request Monetization",
                                          style: TextStyle(color: textColor),
                                        ),
                                        trailing: Icon(Icons.arrow_forward_ios,
                                            size: 14, color: textColor),
                                        onTap: () => NavigationHelper.push(
                                            context,
                                            const MonetizationRequestPage()),
                                      ),
                                      _buildDivider(isDark),
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(
                                            Icons.account_balance_wallet,
                                            color: Colors.teal),
                                        title: Text(
                                          currentIsMm
                                              ? "ဝင်ငွေနှင့်ဆုလာဘ်များ"
                                              : "Earn & Reward Dashboard",
                                          style: TextStyle(color: textColor),
                                        ),
                                        trailing: Icon(Icons.arrow_forward_ios,
                                            size: 14, color: textColor),
                                        onTap: () => NavigationHelper.push(
                                            context, const EarnAndRewardPage()),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // --- Section 2: Preferences ---
                                _buildSectionHeader(
                                    currentIsMm
                                        ? "စနစ်ပြင်ဆင်ချက်များ"
                                        : "Preferences",
                                    isDark),
                                _buildBlurCard(
                                  boxBgColor: boxBgColor,
                                  child: Column(
                                    children: [
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.language,
                                            color: Colors.blue),
                                        title: Text(
                                          currentIsMm
                                              ? "English သို့ပြောင်းရန်"
                                              : "Switch to Myanmar",
                                          style: TextStyle(color: textColor),
                                        ),
                                        trailing: Switch(
                                          value: currentIsMm,
                                          onChanged: (val) async {
                                            isMyanmarNotifier.value = val;
                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            await prefs.setBool(
                                                'is_myanmar_language', val);
                                          },
                                        ),
                                      ),
                                      _buildDivider(isDark),
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.color_lens,
                                            color: Colors.purple),
                                        title: Text(
                                          currentIsMm
                                              ? "Theme ပြောင်းရန်"
                                              : "Change Theme",
                                          style: TextStyle(color: textColor),
                                        ),
                                        trailing: Icon(Icons.arrow_forward_ios,
                                            size: 14, color: textColor),
                                        onTap: () async {
                                          DocumentSnapshot userDoc =
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .get();
                                          Map<String, dynamic> userData =
                                              userDoc.data()
                                                  as Map<String, dynamic>;
                                          showThemeSelectionDialog(context,
                                              currentIsMm, userData['role']);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // --- Section 3: Support, Safety & Account ---
                                _buildSectionHeader(
                                    currentIsMm
                                        ? "အကူအညီ၊ လုံခြုံရေးနှင့် အကောင့်"
                                        : "Support, Safety & Account",
                                    isDark),
                                _buildBlurCard(
                                  boxBgColor: boxBgColor,
                                  child: Column(
                                    children: [
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.description,
                                            color: Colors.blueAccent),
                                        title: Text(
                                          currentIsMm
                                              ? "စည်းမျဉ်းများနှင့် သတ်မှတ်ချက်များ"
                                              : "Terms of Service",
                                          style: TextStyle(color: textColor),
                                        ),
                                        trailing: Icon(Icons.arrow_forward_ios,
                                            size: 14, color: textColor),
                                        onTap: () => _launchURL(
                                            context, termsOfServiceUrl),
                                      ),
                                      _buildDivider(isDark),
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.privacy_tip,
                                            color: Colors.green),
                                        title: Text(
                                          currentIsMm
                                              ? "ကိုယ်ရေးအချက်အလက် မူဝါဒ"
                                              : "Privacy Policy",
                                          style: TextStyle(color: textColor),
                                        ),
                                        trailing: Icon(Icons.arrow_forward_ios,
                                            size: 14, color: textColor),
                                        onTap: () => _launchURL(
                                            context, privacyPolicyUrl),
                                      ),
                                      _buildDivider(isDark),

                                      // 🚫 Blocked Users Page သို့ သွားမည့် ခလုတ်
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.block,
                                            color: Colors.orange),
                                        title: Text(
                                          currentIsMm
                                              ? "Block ထားသော စာရင်း"
                                              : "Blocked Users",
                                          style: TextStyle(color: textColor),
                                        ),
                                        trailing: Icon(Icons.arrow_forward_ios,
                                            size: 14, color: textColor),
                                        onTap: () => _openBlockedUsersPage(
                                            context, user.uid),
                                      ),
                                      _buildDivider(isDark),

                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.help_outline,
                                            color: Colors.orangeAccent),
                                        title: Text(
                                          currentIsMm
                                              ? "အကူအညီတောင်းခံရန်"
                                              : "Help & Support",
                                          style: TextStyle(color: textColor),
                                        ),
                                        trailing: Icon(Icons.arrow_forward_ios,
                                            size: 14, color: textColor),
                                        onTap: () => NavigationHelper.push(
                                            context, const HelpPage()),
                                      ),
                                      _buildDivider(isDark),
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.logout,
                                            color: Colors.grey),
                                        title: Text(
                                          currentIsMm
                                              ? "အကောင့်ထွက်မည်"
                                              : "Log Out",
                                          style: TextStyle(color: textColor),
                                        ),
                                        onTap: () => _signOut(context),
                                      ),
                                      _buildDivider(isDark),

                                      ListTile(
                                        dense: true,
                                        leading: const Icon(
                                            Icons.delete_forever,
                                            color: Colors.red),
                                        title: Text(
                                          currentIsMm
                                              ? "အကောင့်ဖျက်မည်"
                                              : "Delete Account",
                                          style: const TextStyle(
                                              color: Colors.red),
                                        ),
                                        trailing: Icon(Icons.arrow_forward_ios,
                                            size: 14, color: textColor),
                                        onTap: () {
                                          NavigationHelper.push(context,
                                              const DeleteAccountPage());
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),
                ),
                const BannerAdWidget(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[200],
    );
  }

  Widget _buildBlurCard({required Color boxBgColor, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: boxBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }
}

// 🚫 Blocked Users စာရင်း ကြည့်ရန်နှင့် Unblock လုပ်ရန် Dynamic Theme & Glassmorphism Widget
class BlockedUsersPage extends StatelessWidget {
  final String currentUid;
  const BlockedUsersPage({super.key, required this.currentUid});

  Future<void> _unblockUser(BuildContext context, String blockedUserId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({
        'blockedUsers': FieldValue.arrayRemove([blockedUserId])
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMyanmarNotifier.value
                  ? "အသုံးပြုသူကို Block ဖြုတ်လိုက်ပါပြီ။"
                  : "Unblocked user successfully.",
            ),
          ),
        );
      }
    } catch (e) {
      print("Unblock error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();
    Color boxBgColor =
        isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.4);

    return ValueListenableBuilder<bool>(
      valueListenable: isMyanmarNotifier,
      builder: (context, isMm, child) {
        return Container(
          decoration: themeProvider.getBackgroundDecoration(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              title: Text(
                isMm ? "Block ထားသော စာရင်း" : "Blocked Users",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var userData =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      List blockedUsers = userData?['blockedUsers'] ?? [];

                      if (blockedUsers.isEmpty) {
                        return Center(
                          child: Text(
                            isMm
                                ? "Block ထားသော အသုံးပြုသူများ မရှိပါ။"
                                : "No blocked users.",
                            style: TextStyle(color: textColor),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: blockedUsers.length,
                        itemBuilder: (context, index) {
                          String blockedUid = blockedUsers[index];

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(blockedUid)
                                .get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              var targetData = userSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                              String name = targetData?['displayName'] ??
                                  (isMm ? "အသုံးပြုသူ" : "User");
                              String profilePic =
                                  targetData?['profileImageUrl'] ?? "";

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: boxBgColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: profilePic.isNotEmpty
                                              ? NetworkImage(profilePic)
                                              : null,
                                          child: profilePic.isEmpty
                                              ? const Icon(Icons.person)
                                              : null,
                                        ),
                                        title: Text(
                                          name,
                                          style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        trailing: TextButton(
                                          onPressed: () =>
                                              _unblockUser(context, blockedUid),
                                          child: Text(
                                            isMm ? "Block ဖြုတ်မည်" : "Unblock",
                                            style: const TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const BannerAdWidget(),
              ],
            ),
          ),
        );
      },
    );
  }
}
