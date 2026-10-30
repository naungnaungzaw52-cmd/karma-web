// ignore_for_file: avoid_print, use_build_context_synchronously, unused_field

import 'dart:io';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:karma/main.dart';
import 'package:provider/provider.dart'; // 🌟 ThemeProvider အတွက် Provider ထည့်သွင်းခြင်း
import 'package:karma/pages/other_profile_page.dart';
import 'package:karma/pages/notification_page.dart';
import 'package:badges/badges.dart' as badges;
import 'package:karma/pages/search_page.dart';
import 'package:karma/services/notification_service.dart';
import 'package:karma/services/r2_service.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_compress/video_compress.dart';
import 'package:karma/widgets/story_view_widget.dart';
import 'package:karma/widgets/full_screen_gallery.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:karma/utilis/theme_provider.dart';

class PostModel {
  final String id;
  final String uid;
  final String userName;
  final String userImage;
  final String text;
  final List<String> mediaUrls;
  final String mediaUrl;
  final List<String> taggedUserIds;
  final List<String> likes;
  final List<String> viewedUserIds;
  final DateTime createdAt;

  // Fields များ
  final bool isGolden;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewCount;
  final num totalTips; // 🌟 ထည့်သွင်းရန်

  PostModel({
    required this.id,
    required this.uid,
    required this.userName,
    required this.userImage,
    required this.text,
    required this.mediaUrls,
    required this.mediaUrl,
    required this.taggedUserIds,
    required this.likes,
    required this.viewedUserIds,
    required this.createdAt,
    this.isGolden = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.viewCount = 0,
    this.totalTips = 0, // 🌟 Default value
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    return PostModel(
      id: id,
      uid: map['uid'] ?? '',
      userName: map['userName'] ?? '',
      userImage: map['userImage'] ?? '',
      text: map['text'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      mediaUrl: map['mediaUrl'] ?? '',
      taggedUserIds: List<String>.from(map['taggedUserIds'] ?? []),
      likes: List<String>.from(map['likes'] ?? []),
      viewedUserIds: List<String>.from(map['viewedUserIds'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isGolden: map['isGolden'] ?? false,
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      sharesCount: map['sharesCount'] ?? 0,
      viewCount: map['viewCount'] ?? 0,
      totalTips: map['totalTips'] ?? 0, // 🌟 Map မှ ဖတ်ရန်
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Color _getCardBgColor(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (themeProvider.currentTheme == 'Default') {
      return Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      return Colors.white.withOpacity(0.15); // Glassmorphism ပုံစံ
    } else {
      return Colors.black.withOpacity(0.3); // Dark / Gradient Theme များအတွက်
    }
  }

  double _calculatePostScore(Map<String, dynamic> postData) {
    // 1. Engagement Score (Likes, Comments, Shares)
    int likesCount = postData['likesCount'] ??
        (postData['likes'] is List ? (postData['likes'] as List).length : 0);
    int commentsCount = postData['commentsCount'] ?? 0;
    int sharesCount = postData['sharesCount'] ?? 0;
    int viewCount = postData['viewCount'] ?? 0;

    double engagementScore = (likesCount * 2.0) +
        (commentsCount * 3.0) +
        (sharesCount * 4.0) +
        (viewCount * 0.5);

    // 2. Golden Mark Boost (Admin, VIP, Gold Users တွေအတွက် အမှတ်ပိုပေးရန်)
    bool isGolden = postData['isGolden'] ?? false;
    double goldenBoost = isGolden ? 30.0 : 0.0;

    // 3. Freshness Score (အချိန်ပေါ် မူတည်ပြီး ရမှတ်အကျဘက်သွားရန် - Recency)
    double freshnessScore = 0.0;
    if (postData['createdAt'] != null) {
      var createdAt = (postData['createdAt'] as Timestamp).toDate();
      Duration difference = DateTime.now().difference(createdAt);
      double hoursAgo = difference.inHours.toDouble();

      // အချိန်ကြာလာလေ အမှတ်လျော့သွားလေ (ဥပမာ - နာရီ ၂၄ နာရီကြာတိုင်း အမှတ်လျော့မည်)
      freshnessScore = 100.0 / (1.0 + (hoursAgo / 12.0));
    }

    // စုစုပေါင်း Score
    return engagementScore + goldenBoost + freshnessScore;
  }

  void showTipModal(BuildContext context, String receiverId,
      String receiverName, String postId) {
    final TextEditingController amountController = TextEditingController();
    final String? senderId = FirebaseAuth.instance.currentUser?.uid;

    if (senderId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please login first")));
      return;
    }

    // 🌟 Theme Provider ချိတ်ဆက်ခြင်း (Notification ပုံစံအတိုင်း အရောင်သတ်မှတ်ရန်)
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool isDark = (themeProvider.currentTheme != 'Default');

    // Notification စာမျက်နှာသုံး cardColor ပုံစံအတိုင်း ယူထားပါသည်
    Color modalBgColor;
    if (themeProvider.currentTheme == 'Default') {
      modalBgColor = Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      modalBgColor = const Color(0xFF1E1E1E)
          .withOpacity(0.85); // Theme နဲ့လိုက်မယ့် ပုံစံမှိန်မှိန်
    } else {
      modalBgColor = const Color(0xFF121212).withOpacity(
          0.85); // Dark/Gradient Theme များအတွက် အနောက်မြင်ရမည့် မှိန်မှိန်အရောင်
    }

    Color textColor = themeProvider.getTextColor();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          modalBgColor, // 🌟 Theme အလိုက် မှိန်မှိန် Background အရောင်
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Send 🔥Tip to $receiverName",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor, // 🌟 Theme အလိုက် စာသားအရောင်
              ),
            ),
            const SizedBox(height: 10),
            // လက်ရှိ Balance ပြပေးခြင်း
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(senderId)
                  .snapshots(),
              builder: (context, snapshot) {
                num myBalance = snapshot.hasData
                    ? (snapshot.data!.data()
                            as Map<String, dynamic>)['balance'] ??
                        0
                    : 0;
                return Text(
                  "Available Balance: $myBalance K-Points",
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Enter Amount (K-Points)",
                labelStyle: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[600],
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                _processTip(context, senderId, receiverId,
                    num.tryParse(amountController.text) ?? 0, postId);
              },
              child: const Text("Confirm Tip"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(
      String postId, List likes, String postOwnerId) async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    User? currentUser = FirebaseAuth.instance.currentUser;
    String userName = currentUser?.displayName ?? "Unknown User";

    DocumentSnapshot senderDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    String senderAvatar = '';
    if (senderDoc.exists) {
      var data = senderDoc.data() as Map<String, dynamic>?;
      senderAvatar = data?['profileImageUrl'] ??
          data?['profileImage'] ??
          data?['photoURL'] ??
          currentUser?.photoURL ??
          '';
    }

    // 🌟 Post ပိုင်ရှင်၏ Monetization Status ကို စစ်ဆေးရန်
    DocumentReference ownerRef =
        FirebaseFirestore.instance.collection('users').doc(postOwnerId);
    DocumentSnapshot ownerDoc = await ownerRef.get();
    bool isMonetized = false;
    if (ownerDoc.exists) {
      var ownerData = ownerDoc.data() as Map<String, dynamic>?;
      isMonetized = (ownerData?['monetizationStatus'] == 'approved');
    }

    if (likes.contains(uid)) {
      // Unlike လုပ်ခြင်း
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(
            FirebaseFirestore.instance.collection('posts').doc(postId), {
          'likes': FieldValue.arrayRemove([uid]),
          'likesCount': FieldValue.increment(-1),
        });

        // Monetization အောင်ထားပါက Like ဖြုတ်လျှင် 50 ကျပ် လျော့မည်
        if (isMonetized) {
          transaction.update(ownerRef, {
            'balance': FieldValue.increment(-50),
          });
        }
      });
    } else {
      // Like လုပ်ခြင်း
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(
            FirebaseFirestore.instance.collection('posts').doc(postId), {
          'likes': FieldValue.arrayUnion([uid]),
          'likesCount': FieldValue.increment(1),
        });

        // Monetization အောင်ထားပါက Like အတွက် ၅၀ ကျပ် ပေါင်းမည်
        if (isMonetized) {
          transaction.update(ownerRef, {
            'balance': FieldValue.increment(50),
          });
        }
      });

      if (postOwnerId != uid) {
        String msg = "$userName is liking your post";
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': postOwnerId,
          'senderId': uid,
          'senderAvatar': senderAvatar,
          'postId': postId,
          'message': msg,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (ownerDoc.exists && ownerDoc['fcmToken'] != null) {
          NotificationService.sendNotification(
              ownerDoc['fcmToken'], msg, "New Like!", 'message');
        }
      }
    }
  }

  Future<void> _deletePost(String postId,
      {String? mediaUrl, List<dynamic>? mediaUrls}) async {
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      await R2Service.deleteFile(mediaUrl);
    }
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      for (var url in mediaUrls) {
        await R2Service.deleteFile(url.toString());
      }
    }
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
  }

  Future<void> _processTip(BuildContext context, String senderId,
      String receiverId, num amount, String postId) async {
    if (amount <= 0) return;

    // 🌟 လက်ရှိ Language ကို စစ်ဆေးရန် (True ဆိုရင် မြန်မာ၊ False ဆိုရင် English)
    bool isMm = isMyanmarNotifier.value;

    final firestore = FirebaseFirestore.instance;
    final senderRef = firestore.collection('users').doc(senderId);
    final receiverRef = firestore.collection('users').doc(receiverId);
    final postRef = firestore.collection('posts').doc(postId);

    try {
      await firestore.runTransaction((transaction) async {
        final senderDoc = await transaction.get(senderRef);
        num senderBalance = senderDoc['balance'] ?? 0;

        if (senderBalance < amount) {
          throw Exception(
              isMm ? "လက်ကျန်ငွေ မလုံလောက်ပါ။" : "Insufficient balance");
        }

        // 1. Sender ထဲက Balance နှုတ်မည်
        transaction
            .update(senderRef, {'balance': FieldValue.increment(-amount)});

        // 2. Receiver ထဲကို Balance ပေါင်းထည့်မည်
        transaction
            .update(receiverRef, {'balance': FieldValue.increment(amount)});

        // 3. သက်ဆိုင်ရာ Post ရဲ့ totalTips ကို ပေါင်းမည် (Tip လက်ခံရရှိသောကြောင့်)
        transaction.update(postRef, {
          'totalTips': FieldValue.increment(amount),
        });

        // 4. Notification ပို့ရန်
        transaction.set(firestore.collection('notifications').doc(), {
          'receiverId': receiverId,
          'senderId': senderId,
          'message': isMm
              ? "🔥 သင့် Post အား $amount K-Points Tip ပေးခဲ့ပါသည်။"
              : "🔥 Sent you a tip of $amount K-Points on your post.",
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      });

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm ? "Tip ပေးပို့မှု အောင်မြင်ပါသည်။" : "Tip sent successfully.",
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? "အမှားအယွင်း ရှိပါသည်: ${e.toString().replaceAll('Exception: ', '')}"
                : "Error: ${e.toString().replaceAll('Exception: ', '')}",
          ),
        ),
      );
    }
  }

  void _showReportDialog(
      BuildContext context, String postId, String postContent) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool isDarkMode = themeProvider.currentTheme != 'Default';

    // 🌟 Theme အလိုက် Dialog Background အရောင်
    Color dialogBgColor;
    if (themeProvider.currentTheme == 'Default') {
      dialogBgColor = Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      dialogBgColor = Colors.white.withOpacity(0.2); // Glassmorphism style
    } else {
      dialogBgColor =
          const Color(0xFF1E1E1E).withOpacity(0.8); // Dark themes အတွက်
    }

    showDialog(
      context: context,
      barrierColor: Colors.black
          .withOpacity(0.3), // 👈 Dialog ရဲ့ အပြင်ဘက်ကို အနည်းငယ်မှောင်စေရန်
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: 10, sigmaY: 10), // 👈 နောက်ခံ Blur ဖြစ်သွားစေရန်
        child: ValueListenableBuilder<bool>(
          valueListenable:
              isMyanmarNotifier, // 🌟 Language အပြောင်းအလဲကို စောင့်ကြည့်ရန်
          builder: (context, isMm, child) {
            // 🌟 မြန်မာ / အင်္ဂလိပ် အကြောင်းပြချက်များ
            List<String> reasons = isMm
                ? [
                    "မသင့်လျော်သော အကြောင်းအရာ (NSFW/18+)",
                    "အကြမ်းဖက်ခြင်း သို့မဟုတ် အနိုင်ကျင့်ခြင်း",
                    "လိမ်လည်လှည့်ဖြားမှု (Spam)",
                    "အခြားအကြောင်းပြချက်"
                  ]
                : [
                    "Inappropriate Content (NSFW/18+)",
                    "Violence or Bullying",
                    "Spam or Fraud",
                    "Other reason"
                  ];

            String selectedReason = reasons[0];

            return StatefulBuilder(
              builder: (dialogContext, setState) => AlertDialog(
                backgroundColor: dialogBgColor, // 👈 Theme အလိုက် အရောင်
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color:
                          Colors.white.withOpacity(0.2)), // အနားသတ် လင်းလင်းလေး
                ),
                title: Text(
                  isMm ? "ဤပို့စ်ကို အစီရင်ခံရန် (Report)" : "Report this post",
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMm
                          ? "အကြောင်းရင်းကို ရွေးချယ်ပါ -"
                          : "Select a reason -",
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...reasons.map((reason) => RadioListTile<String>(
                          title: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          activeColor: Colors.blueAccent,
                          value: reason,
                          groupValue: selectedReason,
                          onChanged: (value) {
                            setState(() {
                              selectedReason = value!;
                            });
                          },
                        )),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      isMm ? "မလုပ်တော့ပါ" : "Cancel",
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      String currentUid =
                          FirebaseAuth.instance.currentUser?.uid ?? "";

                      await FirebaseFirestore.instance
                          .collection('reports')
                          .add({
                        'postId': postId,
                        'postContent': postContent,
                        'reporterId': currentUid,
                        'reason': selectedReason,
                        'createdAt': FieldValue.serverTimestamp(),
                        'status': 'pending',
                      });

                      if (!context.mounted) return;
                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isMm
                                ? "Report တင်သွင်းပြီးပါပြီ။ ကျေးဇူးတင်ပါသည်။"
                                : "Report submitted successfully. Thank you.",
                          ),
                        ),
                      );
                    },
                    child: Text(isMm ? "တင်မည်" : "Submit"),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showComments(BuildContext context, String postId, String postOwnerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent, // 👈 အနောက်က background ကို ဖောက်မြင်ရအောင်
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: 10, sigmaY: 10), // 👈 Blur effect ထည့်ခြင်း
        child: _CommentBottomSheet(postId: postId, postOwnerId: postOwnerId),
      ),
    );
  }

  void _showShareUserList(
      BuildContext context, String postId, Map<String, dynamic> postData) {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Color textColor = themeProvider.getTextColor();
    bool isDark = themeProvider.currentTheme != 'Default';

    Color modalBgColor;
    if (themeProvider.currentTheme == 'Default') {
      modalBgColor = Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      modalBgColor = Colors.white.withOpacity(0.2);
    } else {
      modalBgColor = Colors.black.withOpacity(0.5);
    }

    TextEditingController searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    decoration: BoxDecoration(
                      color: modalBgColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                        left: 16,
                        right: 16,
                        top: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMm
                                ? "ချတ်ထဲသို့ မျှဝေရန် (Share to Chat)"
                                : "Share to Chat",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: searchController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: isMm
                                  ? "အမည်ဖြင့် ရှာရန်..."
                                  : "Search by name...",
                              hintStyle:
                                  TextStyle(color: textColor.withOpacity(0.5)),
                              prefixIcon: Icon(Icons.search, color: textColor),
                              filled: true,
                              fillColor:
                                  isDark ? Colors.white10 : Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 0),
                            ),
                            onChanged: (value) {
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(currentUser.uid)
                                  .snapshots(),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                var userData = userSnapshot.data!.data()
                                    as Map<String, dynamic>?;

                                List<dynamic> targetIds =
                                    userData?['following'] ?? [];

                                if (targetIds.isEmpty) {
                                  return Center(
                                    child: Text(
                                      isMm
                                          ? "မျှဝေရန် အသုံးပြုသူ မရှိသေးပါ။ (မည်သူ့ကိုမျှ Follow လုပ်ထားခြင်း မရှိသေးပါ)"
                                          : "No users to share with. (You are not following anyone yet)",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: textColor.withOpacity(0.7)),
                                    ),
                                  );
                                }

                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .where(FieldPath.documentId,
                                          whereIn: targetIds)
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    }

                                    var queryText = searchController.text
                                        .trim()
                                        .toLowerCase();
                                    var users =
                                        snapshot.data!.docs.where((doc) {
                                      var data =
                                          doc.data() as Map<String, dynamic>;
                                      String name = (data['displayName'] ??
                                              data['userName'] ??
                                              '')
                                          .toString()
                                          .toLowerCase();
                                      if (queryText.isEmpty) return true;
                                      return name.contains(queryText);
                                    }).toList();

                                    if (users.isEmpty) {
                                      return Center(
                                        child: Text(
                                          isMm
                                              ? "အသုံးပြုသူ မတွေ့ရှိပါ။"
                                              : "No user found.",
                                          style: TextStyle(color: textColor),
                                        ),
                                      );
                                    }

                                    return ListView.builder(
                                      itemCount: users.length,
                                      itemBuilder: (context, index) {
                                        var targetUser = users[index];
                                        var targetData = targetUser.data()
                                            as Map<String, dynamic>;
                                        String targetName =
                                            targetData['displayName'] ??
                                                targetData['userName'] ??
                                                "User";
                                        String? targetAvatar =
                                            targetData['profileImageUrl'] ??
                                                targetData['profileImage'] ??
                                                targetData['photoURL'];

                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundImage:
                                                (targetAvatar != null &&
                                                        targetAvatar.isNotEmpty)
                                                    ? NetworkImage(targetAvatar)
                                                    : null,
                                            child: (targetAvatar == null ||
                                                    targetAvatar.isEmpty)
                                                ? const Icon(Icons.person)
                                                : null,
                                          ),
                                          title: GoldenNameWidget(
                                            name: targetName,
                                            role:
                                                targetData['role'] ?? 'member',
                                            fontSize: 16,
                                          ),
                                          trailing: ElevatedButton(
                                            onPressed: () async {
                                              await _sendPostToChat(
                                                  targetUser.id,
                                                  postId,
                                                  postData);

                                              if (!context.mounted) return;
                                              Navigator.pop(context);

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(isMm
                                                        ? "ပို့စ်ကို ပို့ပြီးပါပြီ"
                                                        : "Post sent")),
                                              );
                                            },
                                            child:
                                                Text(isMm ? "ပို့မည်" : "Send"),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<String> _getChatRoomId(String userId1, String userId2) async {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _sendPostToChat(
      String receiverId, String postId, Map<String, dynamic> postData) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    String senderUid = currentUser.uid;

    // 🌟 လက်ရှိ Language ကို စစ်ဆေးရန် (True ဆိုရင် မြန်မာ၊ False ဆိုရင် English)
    bool isMm = isMyanmarNotifier.value;

    // 1. Sender အချက်အလက်များ ရယူခြင်း
    DocumentSnapshot senderDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(senderUid)
        .get();

    String senderName =
        currentUser.displayName ?? (isMm ? "အသုံးပြုသူ" : "User");
    String senderAvatar = '';
    if (senderDoc.exists) {
      var sData = senderDoc.data() as Map<String, dynamic>?;
      senderName = sData?['displayName'] ?? sData?['userName'] ?? senderName;
      senderAvatar = sData?['profileImageUrl'] ??
          sData?['profileImage'] ??
          sData?['photoURL'] ??
          currentUser.photoURL ??
          '';
    }

    // 2. Chat Room အတည်ပြုခြင်း
    String chatRoomId = await _getChatRoomId(senderUid, receiverId);
    DocumentReference chatRoomRef =
        FirebaseFirestore.instance.collection('chats').doc(chatRoomId);

    // Chat Room document ရှိမရှိ စစ်ဆေးပြီး အသစ်ဖြစ်ပါက ဖန်တီးပေးခြင်း
    DocumentSnapshot chatDoc = await chatRoomRef.get();
    if (!chatDoc.exists) {
      await chatRoomRef.set({
        'participants': [senderUid, receiverId],
        'lastMessage': isMm ? "ပို့စ်တစ်ခု မျှဝေထားသည်" : "Shared a post",
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. Message ပို့ခြင်း
    String postText = postData['text'] ?? '';
    String previewText = postText.isNotEmpty
        ? (isMm
            ? "ပို့စ်တစ်ခုကို မျှဝေထားသည်: $postText"
            : "Shared a post: $postText")
        : (isMm ? "ပို့စ်တစ်ခုကို မျှဝေထားသည်" : "Shared a post");

    await chatRoomRef.collection('messages').add({
      'senderId': senderUid,
      'receiverId': receiverId,
      'message': previewText,
      'text': previewText,
      'type': 'shared_post',
      'postId': postId,
      'mediaUrl': postData['mediaUrl'] ??
          (postData['mediaUrls'] != null &&
                  (postData['mediaUrls'] as List).isNotEmpty
              ? postData['mediaUrls'][0]
              : null),
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 4. Post ကို Share Count တိုးခြင်း
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'sharesCount': FieldValue.increment(1),
    });

    // 5. Notification ပို့ခြင်း
    String notiMsg = isMm
        ? "$senderName က သင့်ထံသို့ Post တစ်ခု မျှဝေလာပါသည်။"
        : "$senderName shared a post with you.";

    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': receiverId,
      'senderId': senderUid,
      'senderAvatar': senderAvatar,
      'postId': postId,
      'message': notiMsg,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    DocumentSnapshot receiverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverId)
        .get();
    if (receiverDoc.exists) {
      var rData = receiverDoc.data() as Map<String, dynamic>?;
      if (rData != null && rData['fcmToken'] != null) {
        NotificationService.sendNotification(rData['fcmToken'], notiMsg,
            isMm ? "ပို့စ်အသစ် မျှဝေထားသည်!" : "New Shared Post!", 'message');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color cardColor = _getCardBgColor(context);
    Color textColor = themeProvider.getTextColor();

    return DefaultTabController(
      length: 2,
      child: Container(
        // 🌟 Theme အလိုက် Background ပြောင်းရန်
        decoration: themeProvider.getBackgroundDecoration(),
        child: Scaffold(
          backgroundColor: Colors
              .transparent, // Transparent ထားမှသာ Decoration ပေါ်လာမည်[cite: 14]
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            title: Row(children: [
              const Icon(Icons.cyclone, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text("Karma", style: TextStyle(color: textColor))
            ]),
            actions: [
              IconButton(
                icon: Icon(Icons.search,
                    color: isDark ? Colors.white : Colors.blueAccent),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SearchPage())),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('receiverId', isEqualTo: currentUid)
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return badges.Badge(
                    badgeContent: Text("$count",
                        style: const TextStyle(color: Colors.white)),
                    showBadge: count > 0,
                    child: IconButton(
                        icon: Icon(Icons.notifications, color: textColor),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationPage()))),
                  );
                },
              ),
              IconButton(
                  icon: const Icon(Icons.add_circle,
                      size: 25, color: Colors.blueAccent),
                  onPressed: () => _showPostOptions(context)),
            ],
            bottom: TabBar(
              // 🌟 ရွေးထားသော Tab ရဲ့ စာသားအရောင် (Dark Mode မှာ ပိုလင်းတဲ့အရောင် သုံးပေးနိုင်ပါတယ်)
              labelColor: isDark ? Colors.blue.shade300 : Colors.blueAccent,

              // 🌟 မရွေးရသေးသော Tab ရဲ့ စာသားအရောင်
              unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey,

              // 🌟 အောက်ခံ Indicator အရောင်
              indicatorColor: isDark ? Colors.blue.shade300 : Colors.blueAccent,

              tabs: const [
                Tab(text: "For You"),
                Tab(text: "Following"),
              ],
            ),
          ),
          body: Column(
            children: [
              const StoryViewWidget(),
              const Divider(height: 10),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildAlgorithmicPostList(
                        context, currentUid, cardColor, textColor, isDark),
                    ValueListenableBuilder<bool>(
                      valueListenable: isMyanmarNotifier,
                      builder: (context, isMm, child) {
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(currentUid)
                              .snapshots(),
                          builder: (context, userSnapshot) {
                            if (!userSnapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            var userData = userSnapshot.data!.data()
                                as Map<String, dynamic>?;
                            List<dynamic> followingList =
                                userData?['following'] ?? [];

                            if (followingList.isEmpty) {
                              return Center(
                                child: Text(
                                  isMm
                                      ? "သင်မည်သူ့ကိုမျှ Follow မလုပ်ရသေးပါ"
                                      : "You are not following anyone yet",
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey),
                                ),
                              );
                            }

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('posts')
                                  .where('uid', whereIn: followingList)
                                  .orderBy('createdAt', descending: true)
                                  .snapshots(),
                              builder: (context, postSnapshot) {
                                if (!postSnapshot.hasData) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }

                                final posts = postSnapshot.data!.docs;
                                if (posts.isEmpty) {
                                  return Center(
                                    child: Text(
                                      isMm
                                          ? "Follow ထားသူများ၏ Post များ မရှိသေးပါ"
                                          : "No posts from following users",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey),
                                    ),
                                  );
                                }

                                // 🌟 ဤနေရာတွင် အရင်အတိုင်း parameter ၆ ခုသာ ထည့်ပါ
                                return _buildListView(context, posts,
                                    currentUid, cardColor, textColor, isDark);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlgorithmicPostList(BuildContext context, String currentUid,
      Color cardColor, Color textColor, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var posts = snapshot.data!.docs;

        // 🌟 For You Feed Ranking Algorithm
        posts.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;

          double scoreA = _calculatePostScore(dataA);
          double scoreB = _calculatePostScore(dataB);

          return scoreB.compareTo(scoreA); // ရမှတ်အများဆုံးက ထိပ်ဆုံးမှာလာမယ်
        });

        return _buildListView(
            context, posts, currentUid, cardColor, textColor, isDark);
      },
    );
  }

  Widget _buildListView(BuildContext context, List<QueryDocumentSnapshot> posts,
      String currentUid, Color cardColor, Color textColor, bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    Future<void> handleRefresh() async {
      await Future.delayed(const Duration(milliseconds: 800));
    }

    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          var post = posts[index];
          var postData = post.data() as Map<String, dynamic>;
          List likes = postData.containsKey('likes') ? postData['likes'] : [];
          String postUid = postData['uid'] ?? "";
          String? mediaUrl =
              postData.containsKey('mediaUrl') ? postData['mediaUrl'] : null;
          List<dynamic> mediaUrls =
              postData.containsKey('mediaUrls') ? postData['mediaUrls'] : [];
          String? postUserImage =
              postData.containsKey('userImage') ? postData['userImage'] : null;

          return Card(
            color: cardColor,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(postUid)
                      .get(),
                  builder: (context, userSnapshot) {
                    String? profileImageUrl = postUserImage;
                    if ((profileImageUrl == null || profileImageUrl.isEmpty) &&
                        userSnapshot.hasData &&
                        userSnapshot.data!.exists) {
                      var userData =
                          userSnapshot.data!.data() as Map<String, dynamic>?;
                      if (userData != null) {
                        profileImageUrl = userData['profileImageUrl'] ??
                            userData['profileImage'] ??
                            userData['photoURL'];
                      }
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: (profileImageUrl != null &&
                                profileImageUrl.isNotEmpty)
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child:
                            (profileImageUrl == null || profileImageUrl.isEmpty)
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null,
                      ),
                      title: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(postUid)
                            .get(),
                        builder: (context, userSnapshot) {
                          String name = postData['userName'] ?? "Unknown User";
                          String role = 'member';

                          if (userSnapshot.hasData &&
                              userSnapshot.data!.exists) {
                            var userData = userSnapshot.data!.data()
                                as Map<String, dynamic>?;
                            role = userData?['role'] ?? 'member';
                          }

                          return GoldenNameWidget(
                            name: name,
                            role: role,
                            fontSize: 16,
                            isWhiteBackground: !isDark,
                          );
                        },
                      ),
                      subtitle: Text(
                        postData['createdAt'] != null
                            ? "${postData['createdAt'].toDate().year}-${postData['createdAt'].toDate().month.toString().padLeft(2, '0')}-${postData['createdAt'].toDate().day.toString().padLeft(2, '0')} ${postData['createdAt'].toDate().hour.toString().padLeft(2, '0')}:${postData['createdAt'].toDate().minute.toString().padLeft(2, '0')}"
                            : "",
                        style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey),
                      ),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => OtherProfilePage(
                                  userId: postUid,
                                  userName:
                                      postData['userName'] ?? "Unknown User"))),
                      trailing: PopupMenuButton<String>(
                        // 🌟 Theme အလိုက် Popup Menu Box ရဲ့ Background အရောင်ကို menuBgColor သုံးခြင်း
                        color: themeProvider.currentTheme == 'Default'
                            ? Colors.white
                            : (themeProvider.currentTheme == 'Soft Rose' ||
                                    themeProvider.currentTheme == 'Sunset Glow'
                                ? Colors.white.withOpacity(0.85)
                                : const Color(0xFF1E1E1E).withOpacity(0.9)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: themeProvider.currentTheme == 'Default'
                                ? Colors.transparent
                                : Colors.white
                                    .withOpacity(0.2), // အနားသတ် လင်းလင်းလေး
                          ),
                        ),
                        icon: Icon(Icons.more_vert, size: 20, color: textColor),
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditPostPage(
                                  postId: post.id,
                                  currentText: postData['text'] ?? '',
                                  currentMediaUrl: mediaUrl,
                                  currentMediaUrls:
                                      mediaUrls, // 🌟 ဒီနေရာလေး ထည့်ပေးလိုက်ပါ
                                ),
                              ),
                            );
                          } else if (value == 'delete') {
                            _deletePost(post.id,
                                mediaUrl: mediaUrl, mediaUrls: mediaUrls);
                          } else if (value == 'report') {
                            _showReportDialog(
                                context, post.id, postData['text'] ?? '');
                          }
                        },
                        itemBuilder: (context) {
                          final bool isLight =
                              themeProvider.currentTheme == 'Default';
                          final Color itemTextColor =
                              isLight ? Colors.black87 : Colors.white;

                          return [
                            PopupMenuItem(
                              child: ValueListenableBuilder<bool>(
                                valueListenable: isMyanmarNotifier,
                                builder: (context, isMm, child) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (postUid == currentUid) ...[
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.edit,
                                              size: 18, color: Colors.blue),
                                          title: Text(
                                            isMm ? "ပြင်ရန်" : "Edit",
                                            style:
                                                TextStyle(color: itemTextColor),
                                          ),
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    EditPostPage(
                                                  postId: post.id,
                                                  currentText:
                                                      postData['text'] ?? '',
                                                  currentMediaUrl: mediaUrl,
                                                  currentMediaUrls: mediaUrls,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(Icons.delete,
                                              size: 18, color: Colors.red),
                                          title: Text(
                                            isMm ? "ဖျက်ရန်" : "Delete",
                                            style:
                                                TextStyle(color: itemTextColor),
                                          ),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _deletePost(post.id,
                                                mediaUrl: mediaUrl,
                                                mediaUrls: mediaUrls);
                                          },
                                        ),
                                      ] else ...[
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(
                                              Icons.report_gmailerrorred,
                                              size: 18,
                                              color: Colors.orange),
                                          title: Text(
                                            isMm
                                                ? "Report (အစီရင်ခံရန်)"
                                                : "Report",
                                            style:
                                                TextStyle(color: itemTextColor),
                                          ),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _showReportDialog(context, post.id,
                                                postData['text'] ?? '');
                                          },
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                          ];
                        },
                      ),
                    );
                  },
                ),
                Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: ExpandableText(
                        text: postData['text'] ?? "", textColor: textColor)),
                if (postData['audioUrl'] != null &&
                    postData['audioUrl'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 6.0),
                    child: PostAudioPlayer(audioUrl: postData['audioUrl']),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildMediaWidget(context, postData, post.id),
                ),
                const Divider(height: 1),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        likes.contains(FirebaseAuth.instance.currentUser?.uid)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: Colors.red,
                        size: 22,
                      ),
                      onPressed: () => _toggleLike(post.id, likes, postUid),
                    ),
                    Text("${likes.length}",
                        style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark ? Colors.grey[400] : Colors.grey[700])),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.comment_outlined,
                              size: 22, color: textColor),
                          onPressed: () {
                            _showComments(context, post.id, postUid);
                          },
                        ),
                        Text(
                          '${postData['commentsCount'] ?? 0}',
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.share_outlined,
                              size: 22, color: textColor),
                          onPressed: () {
                            _showShareUserList(context, post.id, postData);
                          },
                        ),
                        Text(
                          "${postData['sharesCount'] ?? 0}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    if (postData['mediaUrl'] != null &&
                        (postData['mediaUrl']
                                .toString()
                                .toLowerCase()
                                .contains('.mp4') ||
                            postData['mediaUrl']
                                .toString()
                                .toLowerCase()
                                .contains('.mov') ||
                            postData['mediaUrl']
                                .toString()
                                .toLowerCase()
                                .contains('.webm') ||
                            postData['mediaUrl']
                                .toString()
                                .toLowerCase()
                                .contains('.mkv'))) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.visibility_outlined,
                          size: 22,
                          color: isDark ? Colors.grey[400] : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "${postData['viewCount'] ?? 0}",
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        showTipModal(
                          context,
                          postData['uid'],
                          postData['userName'],
                          post.id,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            "${postData['totalTips'] ?? 0} K-Points Tips",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMediaWidget(
      BuildContext context, Map<String, dynamic> postData, String id) {
    List<dynamic> rawUrls = postData['mediaUrls'] ?? [];
    List<String> mediaUrls = rawUrls.map((e) => e.toString()).toList();

    String? mediaUrl = postData['mediaUrl'];
    if (mediaUrls.isEmpty && mediaUrl != null && mediaUrl.isNotEmpty) {
      mediaUrls.add(mediaUrl);
    }

    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    // 🌟 1. ဗီဒီယို တစ်ခုတည်းရှိလျှင် (Landscape / Portrait အလိုက် ဆိုဒ်အပြည့်ပေါ်စေရန်)
    if (!_isImageUrl(mediaUrls[0]) && mediaUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 /
              9, // လိုအပ်သော standard ratio သို့မဟုတ် Video Controller ၏ အချိုးအစား
          child: PostVideoPlayer(
            videoUrl: mediaUrls[0],
            userName: postData['userName'] ?? '',
            profileImageUrl: postData['userImage'] ?? '',
            role: postData['role'] ?? '',
            uid: postData['uid'] ?? '',
            postId: id,
          ),
        ),
      );
    }

    // 🌟 2. ပုံ တစ်ပုံတည်းရှိလျှင် (Landscape ဖြစ်စေ၊ Portrait ဖြစ်စေ မူရင်းအချိုးအစားအတိုင်း အပြည့်ပြရန်)
    if (mediaUrls.length == 1) {
      return GestureDetector(
        onTap: () => _showFullScreenGallery(context, mediaUrls, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(
              maxHeight: 400, // ပုံအရမ်းရှည်သွားပါက အများဆုံးသတ်မှတ်ချက်
              minHeight: 200,
            ),
            width: double.infinity,
            child: Image.network(
              mediaUrls[0],
              fit: BoxFit
                  .cover, // ပုံအပြည့်လှပစွာပေါ်စေရန် (သို့မဟုတ် BoxFit.contain ဖြင့် မူရင်းပုံအတိုင်းအပြည့်ပြရန်)
              width: double.infinity,
            ),
          ),
        ),
      );
    }

    // 🌟 3. ပုံများစွာပါပါက Grid ပုံစံဖြင့် တူညီစွာပြသရန်
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: mediaUrls.length > 4 ? 4 : mediaUrls.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1.0,
        ),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _showFullScreenGallery(context, mediaUrls, index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(mediaUrls[index], fit: BoxFit.cover),
                if (index == 3 && mediaUrls.length > 4)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: Text(
                      "+${mediaUrls.length - 4}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenGallery(
      BuildContext context, List<String> mediaUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenGalleryScreen(
          mediaUrls: mediaUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  bool _isImageUrl(String url) {
    final lowercase = url.toLowerCase();
    return lowercase.contains('.jpg') ||
        lowercase.contains('.jpeg') ||
        lowercase.contains('.png') ||
        lowercase.contains('.webp') ||
        (!lowercase.contains('.mp4') &&
            !lowercase.contains('.mov') &&
            !lowercase.contains('.avi'));
  }

  void _showPostOptions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePostPage(initialMode: 'media'),
      ),
    );
  }
}

// -------------------------------------------------------------
// Mention ပံ့ပိုးပေးထားသော Text Field Widget
// -------------------------------------------------------------
class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(List<String> taggedIds) onSubmitted;

  const MentionTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  bool _showSuggestions = false;
  String _searchQuery = "";
  final List<String> _taggedUserIds = [];

  @override
  void initState() {
    super.initState();
    // 🌟 ဒီနေရာမှာ widget.controller ကို တိုက်ရိုက် listener ချိတ်ပါ
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (!mounted) return;

    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (selection.baseOffset > 0 && selection.baseOffset <= text.length) {
      final uptoCursor = text.substring(0, selection.baseOffset);
      final lastAtIndex = uptoCursor.lastIndexOf('@');

      if (lastAtIndex != -1) {
        final query = uptoCursor.substring(lastAtIndex + 1);
        if (!query.contains(' ')) {
          setState(() {
            _showSuggestions = true;
            _searchQuery = query;
          });
          return;
        }
      }
    }
    setState(() {
      _showSuggestions = false;
    });
  }

  void _selectUser(Map<String, dynamic> user, String userId) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (selection.baseOffset < 0 || selection.baseOffset > text.length) return;

    final uptoCursor = text.substring(0, selection.baseOffset);
    final lastAtIndex = uptoCursor.lastIndexOf('@');

    if (lastAtIndex == -1) return;

    final afterCursor = text.substring(selection.baseOffset);

    final String userName = user['userName'] ??
        user['name'] ??
        user['fullName'] ??
        user['displayName'] ??
        'Unknown User';
    final newText = "${text.substring(0, lastAtIndex)}@$userName $afterCursor";

    widget.controller.text = newText;
    widget.controller.selection =
        TextSelection.collapsed(offset: lastAtIndex + userName.length + 2);

    if (!_taggedUserIds.contains(userId)) {
      _taggedUserIds.add(userId);
    }

    widget.onSubmitted(_taggedUserIds);

    setState(() {
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showSuggestions)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4)
              ],
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var users = snapshot.data!.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      String name = (data['userName'] ??
                              data['name'] ??
                              data['fullName'] ??
                              data['displayName'] ??
                              '')
                          .toString()
                          .toLowerCase();
                      return name.contains(_searchQuery.toLowerCase()) &&
                          doc.id != FirebaseAuth.instance.currentUser?.uid;
                    }).toList();

                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          isMm ? "အသုံးပြုသူ မတွေ့ရှိပါ။" : "No user found.",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        var userDoc = users[index];
                        var userData = userDoc.data() as Map<String, dynamic>;

                        String name = userData['userName'] ??
                            userData['name'] ??
                            userData['fullName'] ??
                            userData['displayName'] ??
                            (isMm ? 'အသုံးပြုသူ' : 'User');
                        String? img = userData['profileImageUrl'] ??
                            userData['profileImage'] ??
                            userData['photoURL'];

                        String rawRole = userData['role'] ??
                            userData['userRole'] ??
                            userData['accountType'] ??
                            'member';
                        String role = rawRole.toLowerCase().trim();

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (img != null && img.isNotEmpty)
                                ? NetworkImage(img)
                                : null,
                            child: (img == null || img.isEmpty)
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: GoldenNameWidget(
                                  name: name,
                                  role: role,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            "@$name",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                          onTap: () => _selectUser(userData, userDoc.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        TextField(
          controller: widget.controller,
          maxLines: null,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: InputBorder.none,
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Comment Bottom Sheet (ThemeProvider Support ထည့်သွင်းပြီး)
// -------------------------------------------------------------
class _CommentBottomSheet extends StatefulWidget {
  final String postId;
  final String postOwnerId;

  const _CommentBottomSheet({required this.postId, required this.postOwnerId});

  @override
  State<_CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<_CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();

  List<DocumentSnapshot> _userSuggestions = [];
  bool _showSuggestions = false;

  bool _isEditing = false;
  String? _editingCommentId;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    final text = _commentController.text;
    final selection = _commentController.selection;

    if (selection.baseOffset > 0) {
      final subText = text.substring(0, selection.baseOffset);
      final lastAtIndex = subText.lastIndexOf('@');

      if (lastAtIndex != -1) {
        final query = subText.substring(lastAtIndex + 1);
        if (!query.contains(' ')) {
          _fetchUserSuggestions(query);
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  Future<void> _fetchUserSuggestions(String query) async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('displayName')
          .startAt([query])
          .endAt(['$query\uf8ff'])
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          _userSuggestions = snapshot.docs;
          _showSuggestions = snapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print("Error fetching user suggestions: $e");
    }
  }

  void onUserSelected(Map<String, dynamic> userData) {
    final text = _commentController.text;
    final selection = _commentController.selection;
    if (selection.baseOffset > 0) {
      final subText = text.substring(0, selection.baseOffset);
      final lastAtIndex = subText.lastIndexOf('@');

      if (lastAtIndex != -1) {
        String displayName = userData['displayName'] ?? 'User';
        final newText = text.replaceRange(
            lastAtIndex, selection.baseOffset, '@$displayName ');

        _commentController.text = newText;
        _commentController.selection = TextSelection.fromPosition(
          TextPosition(offset: lastAtIndex + displayName.length + 2),
        );
      }
    }

    setState(() {
      _showSuggestions = false;
    });
  }

  Future<void> _saveComment() async {
    if (_commentController.text.trim().isEmpty) return;
    String commentText = _commentController.text.trim();

    String currentUid = FirebaseAuth.instance.currentUser!.uid;
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (_isEditing && _editingCommentId != null) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(_editingCommentId)
          .update({
        'text': commentText,
        'isEdited': true,
      });

      setState(() {
        _isEditing = false;
        _editingCommentId = null;
      });
    } else {
      // 🌟 1. ယနေ့ ဒီ Post မှာ ဒီ User Comment ပေးထားတဲ့ အရေအတွက်ကို စစ်ဆေးခြင်း
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);

      var existingComments = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .where('uid', isEqualTo: currentUid)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // 🌟 ၂။ တစ်နေ့လျှင် အများဆုံး ၁၀ ကြိမ် သတ်မှတ်ချက်ကို စစ်ဆေးမည်
      if (existingComments.docs.length >= 10) {
        if (!mounted) return;

        // SnackBar အစား သေချာပေါက် ပေါ်လာမည့် Dialog ကို အသုံးပြုခြင်း
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return AlertDialog(
                  title:
                      Text(isMm ? "ကန့်သတ်ချက် ပြည့်ပါပြီ" : "Limit Reached"),
                  content: Text(
                    isMm
                        ? "ဤ Post တွင် ယနေ့အတွက် Comment ပေးခွင့် (၁၀ ကြိမ်) ပြည့်သွားပါပြီ။"
                        : "You have reached the limit of 10 comments for this post today.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isMm ? "ကောင်းပါပြီ" : "OK"),
                    ),
                  ],
                );
              },
            );
          },
        );
        return;
      }

      String userName = currentUser?.displayName ?? "Unknown User";

      DocumentSnapshot senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      String senderAvatar = '';
      if (senderDoc.exists) {
        var data = senderDoc.data() as Map<String, dynamic>?;
        userName = data?['displayName'] ?? userName;
        senderAvatar = data?['profileImageUrl'] ??
            data?['profileImage'] ??
            data?['photoURL'] ??
            currentUser?.photoURL ??
            '';
      }

      DocumentReference ownerRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.postOwnerId);

      // 🌟 2. [အဓိက ပြင်ဆင်ချက်] Transaction မစခင်မှာ Post Owner ရဲ့ Data ကို အရင် Read (ဖတ်) ပါ
      DocumentSnapshot? ownerDoc;
      if (currentUid != widget.postOwnerId) {
        ownerDoc = await ownerRef.get();
      }

      // 🌟 3. Read လုပ်စရာရှိတာ ပြီးမှ Transaction စတင်ခြင်း (Write တွေချည်းပဲ ဆက်လုပ်မည်)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference commentRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc();

        transaction.set(commentRef, {
          'uid': currentUid,
          'text': commentText,
          'userName': userName,
          'userImage': senderAvatar,
          'createdAt': FieldValue.serverTimestamp(),
        });

        DocumentReference postRef =
            FirebaseFirestore.instance.collection('posts').doc(widget.postId);
        transaction.update(postRef, {
          'commentsCount': FieldValue.increment(1),
        });

        // ကိုယ့် Post ကိုကိုယ် Comment ပေးတာ မဟုတ်မှသာ ၃ ကျပ် ပေါင်းမည်
        if (currentUid != widget.postOwnerId &&
            ownerDoc != null &&
            ownerDoc.exists) {
          var ownerData = ownerDoc.data() as Map<String, dynamic>?;
          if (ownerData?['monetizationStatus'] == 'approved') {
            transaction.update(ownerRef, {
              'balance': FieldValue.increment(30),
            });
          }
        }
      });

      // 4. Notification ပို့ခြင်းနှင့် Mention များအတွက်
      if (currentUid != widget.postOwnerId) {
        String msg = "$userName is commenting on your post: $commentText";
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': widget.postOwnerId,
          'senderId': currentUid,
          'senderAvatar': senderAvatar,
          'postId': widget.postId,
          'message': msg,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        DocumentSnapshot ownerFcmDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.postOwnerId)
            .get();
        if (ownerFcmDoc.exists && ownerFcmDoc['fcmToken'] != null) {
          NotificationService.sendNotification(
              ownerFcmDoc['fcmToken'], msg, "New Comment!", 'message');
        }
      }

      await _checkAndSendMentionNotifications(
          commentText, currentUid, userName, senderAvatar, widget.postId);
    }

    _commentController.clear();
    setState(() {
      _showSuggestions = false;
    });
  }

  Future<void> _deleteComment(String postId, String commentId,
      String postOwnerId, String commentAuthorUid) async {
    DocumentReference ownerRef =
        FirebaseFirestore.instance.collection('users').doc(postOwnerId);

    // 🌟 1. Transaction မစခင် Post Owner ရဲ့ Data ကို အရင် Read (ဖတ်) ပါ
    DocumentSnapshot? ownerDoc;
    // ကိုယ့် Post ကိုကိုယ် Comment ပေးထားတာ မဟုတ်မှသာ Balance ကို စစ်ဆေးရန် Read လုပ်မည်
    if (commentAuthorUid != postOwnerId && commentAuthorUid.isNotEmpty) {
      ownerDoc = await ownerRef.get();
    }

    // 🌟 2. Transaction စတင်ခြင်း
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      // 1. Comment ကို ဖျက်ရန် Reference (မရှိတော့ရင်တောင် Error မတက်စေရန် delete ဆက်လုပ်မည်)
      DocumentReference commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);
      transaction.delete(commentRef);

      // 2. Post ၏ commentsCount ကို ၁ လျော့မည် (သုညအောက် မကျသွားအောင် လိုအပ်လျှင် ထိန်းနိုင်သည်)
      DocumentReference postRef =
          FirebaseFirestore.instance.collection('posts').doc(postId);
      transaction.update(postRef, {
        'commentsCount': FieldValue.increment(-1),
      });

      // 3. 🌟 Balance ပြန်လျော့မည့် အပိုင်း (ပိုမိုသေချာစေရန် condition ကို လွယ်ကူစေခြင်း)
      // Comment ပေးခဲ့သူသည် Post Owner ကိုယ်တိုင် မဟုတ်ခဲ့လျှင် (အခြားသူ လာပေးထားသည့် Comment ဖြစ်လျှင်)
      if (commentAuthorUid != postOwnerId &&
          ownerDoc != null &&
          ownerDoc.exists) {
        var ownerData = ownerDoc.data() as Map<String, dynamic>?;
        if (ownerData?['monetizationStatus'] == 'approved') {
          // Balance ထဲတွင် ငွေအလုံအလောက်ရှိမရှိ စစ်ဆေးပြီးမှ -30 လျော့ခြင်း (သို့မဟုတ် တိုက်ရိုက် -30 လျော့ခြင်း)
          double currentBalance = (ownerData?['balance'] ?? 0).toDouble();
          double newBalance = currentBalance >= 30 ? currentBalance - 30 : 0;

          transaction.update(ownerRef, {
            'balance':
                newBalance, // ၃၀ ကျပ် (သို့မဟုတ် ကျန်ငွေအတိုင်း) တိတိကျကျ ပြန်လົງမညີ
          });
        }
      }
    });
  }

  Future<void> _checkAndSendMentionNotifications(
      String commentText,
      String senderId,
      String senderName,
      String senderAvatar,
      String postId) async {
    // 🌟 လက်ရှိ Language ကို စစ်ဆေးရန် (True ဆိုရင် မြန်မာ၊ False ဆိုရင် English)
    bool isMm = isMyanmarNotifier.value;

    final RegExp regExp = RegExp(r'@([a-zA-Z0-9_\u1000-\u109F\s]+)');
    final matches = regExp.allMatches(commentText);

    for (var match in matches) {
      String mentionedName = match.group(1)!.trim();

      var userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isEqualTo: mentionedName)
          .get();

      for (var userDoc in userQuery.docs) {
        String mentionedUserId = userDoc.id;

        if (mentionedUserId == senderId) continue;

        String mentionMsg = isMm
            ? "$senderName က သင့်ကို Comment တစ်ခုတွင် Mention ခေါ်ထားပါတယ်"
            : "$senderName mentioned you in a comment.";

        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': mentionedUserId,
          'senderId': senderId,
          'senderAvatar': senderAvatar,
          'postId': postId,
          'message': mentionMsg,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (userDoc.data()['fcmToken'] != null) {
          NotificationService.sendNotification(userDoc['fcmToken'], mentionMsg,
              isMm ? "Mention ခေါ်ဆိုမှု အသစ်!" : "New Mention!", 'message');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');

    Color sheetBgColor = isDark
        ? const Color(0xFF1E1E1E).withOpacity(0.15)
        : Colors.white.withOpacity(0.15);

    Color textColor = themeProvider.getTextColor();
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Padding(
      // 🌟 ၁။ ဖုန်းရဲ့ Keyboard ပေါ်လာတဲ့အခါ အပေါ်ကို အလိုက်သင့် တက်လာစေရန် viewInsets ကို padding အဖြစ် သုံးခြင်း
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: sheetBgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.5),
            width: 1.0,
          ),
        ),
        // 🌟 ၂။ padding ထဲမှာ bottom ကို ကျစ်ကျစ်လျစ်လျစ်လေး ဖြစ်စေရန် ချိန်ညှိခြင်း
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16,
        ),
        child: Column(
          children: [
            // အပေါ်ပိုင်း Handle bar လေး (ရှိပြီးသားဆိုရင် ဆက်သုံးပါ)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: isMyanmarNotifier,
                builder: (context, isMm, child) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.postId)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      var docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            isMm ? "Comment မရှိသေးပါ။" : "No comments yet.",
                            style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var doc = docs[index];
                          var data = doc.data() as Map<String, dynamic>;

                          String commentUid = data['uid'] ?? '';
                          String name = data['userName'] ??
                              (isMm ? "အသုံးပြုသူ" : "User");
                          String avatar = data['userImage'] ?? "";
                          String commentText = data['text'] ?? "";
                          bool isEdited = data['isEdited'] ?? false;

                          bool canModify = (commentUid == currentUid) ||
                              (widget.postOwnerId == currentUid);

                          return ListTile(
                            // 🌟 1. ပုံကို နှိပ်လျှင်လည်း ပရိုဖိုင်သို့ သွားရန် GestureDetector ထည့်ခြင်း
                            leading: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OtherProfilePage(
                                      userId: commentUid,
                                      userName: '',
                                    ),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                backgroundImage: avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar.isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                            ),

                            // 🌟 2. နာမည်ကို နှိပ်လျှင်လည်း ပရိုဖိုင်သို့ သွားရန် GestureDetector ထည့်ခြင်း
                            title: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OtherProfilePage(
                                      userId: commentUid,
                                      userName: '',
                                    ),
                                  ),
                                );
                              },
                              child: FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(commentUid)
                                    .get(),
                                builder: (context, userSnapshot) {
                                  String role = 'member';
                                  if (userSnapshot.hasData &&
                                      userSnapshot.data!.exists) {
                                    var userData = userSnapshot.data!.data()
                                        as Map<String, dynamic>?;
                                    role = userData?['role'] ?? 'member';
                                  }

                                  return Row(
                                    children: [
                                      GoldenNameWidget(
                                        name: name,
                                        role: role,
                                        fontSize: 14,
                                        isWhiteBackground: !isDark,
                                      ),
                                      if (isEdited) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          isMm ? "(ပြင်ဆင်ပြီး)" : "(Edited)",
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 10),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                            subtitle: Text(
                              commentText,
                              style: TextStyle(color: textColor),
                            ),
                            trailing: canModify
                                ? PopupMenuButton<String>(
                                    color: themeProvider.currentTheme ==
                                            'Default'
                                        ? Colors.white
                                        : (themeProvider.currentTheme ==
                                                    'Soft Rose' ||
                                                themeProvider.currentTheme ==
                                                    'Sunset Glow'
                                            ? Colors.white.withOpacity(0.85)
                                            : const Color(0xFF1E1E1E)
                                                .withOpacity(0.9)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: themeProvider.currentTheme ==
                                                'Default'
                                            ? Colors.transparent
                                            : Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    icon: Icon(Icons.more_vert,
                                        size: 18, color: textColor),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        setState(() {
                                          _isEditing = true;
                                          _editingCommentId = doc.id;
                                          _commentController.text = commentText;
                                        });
                                      } else if (value == 'delete') {
                                        _deleteComment(
                                          widget.postId,
                                          doc.id,
                                          widget.postOwnerId,
                                          commentUid,
                                        );
                                      }
                                    },
                                    itemBuilder: (context) {
                                      final bool isLight =
                                          themeProvider.currentTheme ==
                                              'Default';
                                      final Color itemTextColor = isLight
                                          ? Colors.black87
                                          : Colors.white;

                                      return [
                                        if (commentUid == currentUid)
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.edit,
                                                    size: 16,
                                                    color: Colors.blue),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isMm ? "ပြင်ရန်" : "Edit",
                                                  style: TextStyle(
                                                      color: itemTextColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.delete,
                                                  size: 16, color: Colors.red),
                                              const SizedBox(width: 8),
                                              Text(
                                                isMm ? "ဖျက်ရန်" : "Delete",
                                                style: TextStyle(
                                                    color: isLight
                                                        ? Colors.red
                                                        : Colors.redAccent),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ];
                                    },
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            if (_showSuggestions && _userSuggestions.isNotEmpty)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _userSuggestions.length,
                  itemBuilder: (context, index) {
                    var userDoc = _userSuggestions[index];
                    var userData = userDoc.data() as Map<String, dynamic>;
                    String displayName = userData['displayName'] ?? 'User';
                    String avatar = userData['profileImageUrl'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      title: GoldenNameWidget(
                        name: displayName,
                        role: userData['role'] ?? 'member',
                        fontSize: 14,
                        isWhiteBackground: !isDark,
                      ),
                      onTap: () => onUserSelected(userData),
                    );
                  },
                ),
              ),
            ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    if (_isEditing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isMm
                                  ? "Comment ကို ပြင်ဆင်နေသည်..."
                                  : "Editing comment...",
                              style: const TextStyle(
                                  color: Colors.blue, fontSize: 12),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _editingCommentId = null;
                                  _commentController.clear();
                                });
                              },
                              child: Text(
                                isMm ? "မလုပ်တော့ပါ" : "Cancel",
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SafeArea(
                      bottom: true,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: _isEditing
                                    ? (isMm
                                        ? "Comment အသစ်ဖြင့် ပြင်ရန်..."
                                        : "Edit with new comment...")
                                    : (isMm
                                        ? "Comment ရေးရန် (@ဖြင့် Mention ခေါ်နိုင်သည်)..."
                                        : "Write a comment (Mention with @)..."),
                                hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey),
                                border: const OutlineInputBorder(),
                                // 🌟 အောက်ခြေခလုတ်တွေနဲ့ မငြိအောင် padding ကို ညှိပေးခြင်း
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                                _isEditing ? Icons.check_circle : Icons.send,
                                color: Colors.blue),
                            onPressed: _saveComment,
                          ),
                        ],
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
  }
}

// -------------------------------------------------------------
// Expandable Text Widget (Mention & Hashtag Support)
// -------------------------------------------------------------
class ExpandableText extends StatefulWidget {
  final String text;
  final Color textColor;
  final int trimWordCount;

  const ExpandableText({
    super.key,
    required this.text,
    required this.textColor,
    this.trimWordCount = 50,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    List<String> words = widget.text.split(RegExp(r'\s+'));
    bool isLongText = words.length > widget.trimWordCount;

    String displayedText = widget.text;
    if (isLongText && !_isExpanded) {
      displayedText = "${words.sublist(0, widget.trimWordCount).join(' ')}...";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Linkify(
          onOpen: (link) async {
            String textUrl = link.url.trim();

            // 🌟 1. Hashtag ဖြစ်နေလျှင် SearchPage သို့သွားမည်
            if (textUrl.startsWith('#') || link.text.startsWith('#')) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(initialQuery: textUrl),
                ),
              );
            }
            // 🌟 2. Mention (@username) ဖြစ်နေလျှင် User ကို Firestore မှရှာပြီး OtherProfilePage သို့သွားမည်
            else if (textUrl.startsWith('@') || link.text.startsWith('@')) {
              String cleanUsername =
                  textUrl.startsWith('@') ? textUrl.substring(1) : textUrl;

              // Firestore တွင် displayName ဖြင့် ရှာဖွေခြင်း
              var userQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('displayName', isEqualTo: cleanUsername)
                  .get();

              if (userQuery.docs.isNotEmpty) {
                String targetUserId = userQuery.docs.first.id;
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OtherProfilePage(
                      userId: targetUserId,
                      userName: cleanUsername,
                    ),
                  ),
                );
              } else {
                // အကယ်၍ displayName နဲ့ မတွေ့ပါက username ဖြင့် ထပ်မံရှာဖွေခြင်း
                var usernameQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .where('username', isEqualTo: cleanUsername)
                    .get();

                if (usernameQuery.docs.isNotEmpty) {
                  String targetUserId = usernameQuery.docs.first.id;
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OtherProfilePage(
                        userId: targetUserId,
                        userName: cleanUsername,
                      ),
                    ),
                  );
                }
              }
            }
            // 🌟 3. ပုံမှန် Website Link များအတွက်
            else {
              final Uri url = Uri.parse(textUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }
          },
          text: displayedText,
          linkifiers: const [
            UrlLinkifier(),
            EmailLinkifier(),
            HashtagLinkifier(),
            MentionLinkifier(), // 👈 ဤနေရာတွင် MentionLinkifier ကို ထည့်ပေးပါ
          ],
          style: TextStyle(
            color: widget.textColor,
            fontSize: 16,
          ),
          linkStyle: const TextStyle(
            color: Colors
                .blueAccent, // Mention နှင့် Hashtag များကို အပြာရောင်ဖြင့် ပြရန်
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
        if (isLongText)
          ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _isExpanded
                        ? (isMm ? "အကျဉ်းချုပ်ပြမည်" : "Show less")
                        : (isMm ? "ဆက်ဖတ်ရန်..." : "Read more..."),
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// -------------------------------------------------------------
// Video WebView Screen & PostVideoPlayer
// -------------------------------------------------------------
class _VideoWebViewScreen extends StatefulWidget {
  final String videoUrl;
  final String userName;
  final String? profileImageUrl;
  final String uid;
  final String postId;
  final dynamic role;

  const _VideoWebViewScreen({
    required this.videoUrl,
    required this.userName,
    this.profileImageUrl,
    required this.uid,
    required this.postId,
    required this.role,
  });

  @override
  State<_VideoWebViewScreen> createState() => _VideoWebViewScreenState();
}

class _VideoWebViewScreenState extends State<_VideoWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    print("=== INIT STATE CALLED ===");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _incrementViewCount();
    });

    // 🌟 ဗီဒီယိုရဲ့ ပထမအစ (Thumbnail) လေး ပေါ်နေစေရန် #t=0.1 ထည့်ထားပါတယ်
    final String thumbVideoUrl = "${widget.videoUrl}#t=0.1";

    final htmlContent = '''
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            html, body { 
              margin: 0; 
              padding: 0;
              background-color: #000; 
              width: 100%; 
              height: 100%; 
              overflow: hidden; 
              display: flex; 
              justify-content: center; 
              align-items: center; 
            }
            video { 
              width: 100%; 
              height: 100%; 
              object-fit: contain; 
            }
          </style>
        </head>
        <body>
          <video id="vid" controls playsinline webkit-playsinline preload="metadata" onplay="sendViewCount()">
            <source src="$thumbVideoUrl" type="video/mp4">
          </video>
          <script>
            let hasPlayed = false;
            function sendViewCount() {
              if (!hasPlayed) {
                hasPlayed = true;
                ViewChannel.postMessage('play_video');
              }
            }

            // 🌟 Landscape video များအတွက် Fullscreen ဝင်ပါက Screen လှည့်ခြင်းကို ထိန်းချုပ်ရန်
            const video = document.getElementById('vid');
            video.addEventListener('fullscreenchange', (event) => {
              if (document.fullscreenElement) {
                // Fullscreen ဝင်သွားချိန် landscape ဖြစ်နေရင် screen orientation ကို ချိန်ညှိရန်
                if (screen.orientation && screen.orientation.lock) {
                  // ဗီဒီယိုရဲ့ အကျယ်နဲ့ အအမြင့်ကို စစ်ပြီး landscape လိုအပ်က lock မည်
                  if (video.videoWidth > video.videoHeight) {
                    screen.orientation.lock('landscape').catch(() => {});
                  }
                }
              } else {
                // Fullscreen ထွက်လျှင် မူလအခြေအနေသို့ ပြန်ို့ရန်
                if (screen.orientation && screen.orientation.unlock) {
                  screen.orientation.unlock();
                }
              }
            });
          </script>
        </body>
      </html>
    ''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'ViewChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'play_video') {
            _incrementViewCount();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadHtmlString(htmlContent);
  }

  Future<void> _incrementViewCount() async {
    print("=== VIEW COUNT METHOD STARTED ===");
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final docRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docSnap = await transaction.get(docRef);
        if (!docSnap.exists) return;

        final data = docSnap.data() as Map<String, dynamic>;
        final List<dynamic> viewedUsers = data['viewedUserIds'] ?? [];

        if (!viewedUsers.contains(currentUser.uid)) {
          final rawView = data['viewCount'];
          int currentViews = (rawView is int)
              ? rawView
              : (int.tryParse(rawView.toString()) ?? 0);

          transaction.update(docRef, {
            'viewedUserIds': FieldValue.arrayUnion([currentUser.uid]),
            'viewCount': currentViews + 1,
          });
        }
      });
    } catch (e) {
      print("View count update CATCH ERROR: $e");
    }
  }

  Future<void> _downloadVideo() async {
    // 🌟 လက်ရှိ Language ကို စစ်ဆေးရန် (True ဆိုရင် မြန်မာ၊ False ဆိုရင် English)
    bool isMm = isMyanmarNotifier.value;

    setState(() {
      _isDownloading = true;
    });

    try {
      final response = await http.get(Uri.parse(widget.videoUrl));
      if (response.statusCode == 200) {
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Karma/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        String fileName =
            "Karma_video_${DateTime.now().millisecondsSinceEpoch}.mp4";
        File file = File('${directory?.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? 'ဗီဒီယို Download ဆွဲပြီးပါပြီ: ${file.path}'
                  : 'Video downloaded successfully: ${file.path}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm ? 'Download လုပ်၍ မအောင်မြင်ပါ: $e' : 'Download failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: (widget.profileImageUrl != null &&
                      widget.profileImageUrl!.isNotEmpty)
                  ? NetworkImage(widget.profileImageUrl!)
                  : null,
              child: (widget.profileImageUrl == null ||
                      widget.profileImageUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.uid)
                    .get(),
                builder: (context, userSnapshot) {
                  String role = 'member';
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    var uData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    role = uData['role'] ?? 'member';
                  }

                  return DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 4.0,
                          color: Colors.black,
                          offset: Offset(1.0, 1.0),
                        ),
                      ],
                    ),
                    child: GoldenNameWidget(
                      name: widget.userName,
                      role: role,
                      fontSize: 16,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return _isDownloading
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: _downloadVideo,
                      tooltip:
                          isMm ? "ဗီဒီယို Download လုပ်ရန်" : "Download Video",
                    );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}

class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String userName;
  final String? profileImageUrl;
  final String uid;
  final String postId;
  final dynamic role;

  const PostVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.userName,
    this.profileImageUrl,
    required this.uid,
    required this.postId,
    required this.role,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late final WebViewController _controller;
  bool _isLoading = true;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();

    final String thumbVideoUrl = "${widget.videoUrl}#t=0.1";

    final htmlContent = '''
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            html, body { 
              margin: 0; 
              padding: 0;
              background-color: #000; 
              width: 100%; 
              height: 100%; 
              overflow: hidden; 
              display: flex; 
              justify-content: center; 
              align-items: center; 
            }
            video { 
              width: 100%; 
              height: 100%; 
              object-fit: contain; 
            }
          </style>
        </head>
        <body>
          <video id="vid" controls playsinline webkit-playsinline preload="metadata" onplay="sendViewCount()">
            <source src="$thumbVideoUrl" type="video/mp4">
          </video>
          <script>
            let hasPlayed = false;
            function sendViewCount() {
              if (!hasPlayed) {
                hasPlayed = true;
                ViewChannel.postMessage('play_video');
              }
            }

            // 🌟 Landscape video များအတွက် Fullscreen ဝင်ပါက Screen လှည့်ခြင်းကို ထိန်းချုပ်ရန်
            const video = document.getElementById('vid');
            video.addEventListener('fullscreenchange', (event) => {
              if (document.fullscreenElement) {
                // Fullscreen ဝင်သွားချိန် landscape ဖြစ်နေရင် screen orientation ကို ချိန်ညှိရန်
                if (screen.orientation && screen.orientation.lock) {
                  // ဗီဒီယိုရဲ့ အကျယ်နဲ့ အအမြင့်ကို စစ်ပြီး landscape လိုအပ်က lock မည်
                  if (video.videoWidth > video.videoHeight) {
                    screen.orientation.lock('landscape').catch(() => {});
                  }
                }
              } else {
                // Fullscreen ထွက်လျှင် မူလအခြေအနေသို့ ပြန်ို့ရန်
                if (screen.orientation && screen.orientation.unlock) {
                  screen.orientation.unlock();
                }
              }
            });
          </script>
        </body>
      </html>
    ''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'ViewChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'play_video') {
            _incrementViewCount();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..loadHtmlString(htmlContent);
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-8755843731256088/3526033189',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd = null;
          _isInterstitialAdLoaded = false;
        },
      ),
    );
  }

  void _showInterstitialAdAndNavigate() {
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _loadInterstitialAd();
          _navigateToWebView();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _navigateToWebView();
        },
      );
      _interstitialAd!.show();
    } else {
      _navigateToWebView();
    }
  }

  void _navigateToWebView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _VideoWebViewScreen(
          videoUrl: widget.videoUrl,
          userName: widget.userName,
          profileImageUrl: widget.profileImageUrl,
          uid: widget.uid,
          postId: widget.postId,
          role: widget.role,
        ),
      ),
    );
  }

  Future<void> _incrementViewCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final docRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docSnap = await transaction.get(docRef);
        if (!docSnap.exists) return;

        final data = docSnap.data() as Map<String, dynamic>;
        final List<dynamic> viewedUsers = data['viewedUserIds'] ?? [];

        if (!viewedUsers.contains(currentUser.uid)) {
          final rawView = data['viewCount'];
          int currentViews = (rawView is int)
              ? rawView
              : (int.tryParse(rawView.toString()) ?? 0);

          transaction.update(docRef, {
            'viewedUserIds': FieldValue.arrayUnion([currentUser.uid]),
            'viewCount': currentViews + 1,
          });
        }
      });
    } catch (e) {
      print("View count update CATCHERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.black,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                _showInterstitialAdAndNavigate();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 20),
                    SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// Create Post Page (ThemeProvider Support နှင့် 1-Min Video / Audio Support ထည့်သွင်းထားသည်)
// -------------------------------------------------------------

class CreatePostPage extends StatefulWidget {
  final String initialMode;
  const CreatePostPage({super.key, required this.initialMode});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _textController = TextEditingController();
  final List<XFile> _selectedImages = [];
  File? _selectedVideo;
  File? _selectedAudio; // 🌟 သီချင်းဖိုင်အတွက်
  String? _videoThumbnailPath;
  bool _isVideo = false;
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  String _progressText = "0%";
  bool _isCancelled = false;
  final List<String> _taggedUserIds = [];
  StateSetter? dialogStateSetter;

  List<String> _hashtagSuggestions = [];
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _showSuggestions = false;
  bool _showUserSuggestions = false;
  String _suggestionType = '';

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      _onTextChanged(_textController.text);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) async {
    final selection = _textController.selection;
    if (selection.baseOffset > 0 && selection.baseOffset <= value.length) {
      final subText = value.substring(0, selection.baseOffset);
      final lastHashIndex = subText.lastIndexOf('#');
      final lastAtIndex = subText.lastIndexOf('@');

      if (lastAtIndex > lastHashIndex && lastAtIndex != -1) {
        final query = subText.substring(lastAtIndex + 1);
        if (!query.contains(' ')) {
          setState(() {
            _suggestionType = 'mention';
            _showSuggestions = false;
          });
          await _fetchUserSuggestions(query);
          return;
        }
      } else if (lastHashIndex > lastAtIndex && lastHashIndex != -1) {
        final query = subText.substring(lastHashIndex).toLowerCase();
        if (!query.contains(' ')) {
          setState(() {
            _suggestionType = 'hashtag';
            _showUserSuggestions = false;
          });
          await _fetchHashtagSuggestions(query);
          return;
        }
      }
    }
    setState(() {
      _showSuggestions = false;
      _showUserSuggestions = false;
      _suggestionType = '';
    });
  }

  Future<void> _fetchHashtagSuggestions(String query) async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('posts').get();

      Set<String> matchedTags = {};
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>?;
        List<dynamic> tags = data?['hashtags'] ?? [];
        for (var tag in tags) {
          String tagStr = tag.toString().toLowerCase();
          if (tagStr.startsWith(query)) {
            matchedTags.add(tag.toString());
          }
        }
      }

      setState(() {
        _hashtagSuggestions = matchedTags.toList();
        _showSuggestions = _hashtagSuggestions.isNotEmpty;
      });
    } catch (e) {
      print("Error fetching hashtags: $e");
    }
  }

  Future<void> _fetchUserSuggestions(String query) async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      List<Map<String, dynamic>> matchedUsers = [];
      String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (doc.id == currentUid) continue;

        String name = (data['userName'] ??
                data['name'] ??
                data['fullName'] ??
                data['displayName'] ??
                '')
            .toString();

        if (name.toLowerCase().contains(query.toLowerCase())) {
          matchedUsers.add({
            'uid': doc.id,
            'name': name,
            'role': data['role'] ?? 'member',
            'image': data['profileImageUrl'] ??
                data['profileImage'] ??
                data['photoURL'] ??
                '',
          });
        }
      }

      setState(() {
        _userSuggestions = matchedUsers;
        _showUserSuggestions = _userSuggestions.isNotEmpty;
      });
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  Future<void> _pickMultipleImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedVideo = null;
        _isVideo = false;
        for (var pickedFile in pickedFiles) {
          _selectedImages.add(pickedFile);
        }
      });
    }
  }

  // Audio Player အတွက် လိုအပ်သော variables တွေ
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  double _audioStartSecond = 0.0;

// 🌟 သီချင်း (Audio) ဖိုင်ရွေးချယ်ရန်နှင့် စက္ကန့် ၂၀ စာ နေရာရွေးချယ်ရန်
  // 🌟 သီချင်း (Audio) ဖိုင်ရွေးချယ်ရန်နှင့် ဖြတ်တောက်မည့်နေရာ (Start & Duration) သတ်မှတ်ရန်
  Future<void> _pickAudio() async {
    bool isMm = isMyanmarNotifier.value;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        File audioFile = File(result.files.single.path!);

        // သီချင်းအရှည်ကို စစ်ဆေးရန် ခေတ္တ Player တစ်ခုဖွင့်မည်
        AudioPlayer tempPlayer = AudioPlayer();
        await tempPlayer.setSource(DeviceFileSource(audioFile.path));

        // သီချင်းရဲ့ စုစုပေါင်းကြာချိန် (Duration) ကို ရယူရန်
        Duration? totalDuration = await tempPlayer.getDuration();
        await tempPlayer.dispose();

        double maxSeconds =
            totalDuration != null ? totalDuration.inSeconds.toDouble() : 60.0;

        if (!mounted) return;

        // 🌟 သီချင်းဘယ်နေရာက စမလဲ နှင့် ဘယ်လောက်ကြာအောင် (Duration) ဖြတ်မလဲ ဆိုတာကို ရွေးမယ့် Dialog
        double startSecond = 0.0;
        double durationSeconds = 20.0; // Default အနေဖြင့် စက္ကန့် ၂၀

        await showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(isMm
                      ? "သီချင်း ဖြတ်တောက်ရန် (Audio Trim)"
                      : "Trim Audio"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMm
                            ? "သီချင်းစတင်မည့် စက္ကန့်ကို ရွေးချယ်ပါ (စုစုပေါင်း: ${maxSeconds.toInt} စက္ကန့်)"
                            : "Select start second (Total: ${maxSeconds.toInt}s)",
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Text("စတင်မည့်နေရာ: ${startSecond.toInt} စက္ကန့်",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: startSecond,
                        min: 0.0,
                        max: maxSeconds > 20 ? maxSeconds - 20 : 0.0,
                        divisions:
                            maxSeconds > 20 ? (maxSeconds - 20).toInt() : 1,
                        label: "${startSecond.toInt} s",
                        onChanged: (val) {
                          setDialogState(() {
                            startSecond = val;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                          "ကြာချိန် (Duration): ${durationSeconds.toInt} စက္ကန့်",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: durationSeconds,
                        min: 5.0,
                        max: 30.0, // အများဆုံး စက္ကန့် ၃၀ အထိ ခွင့်ပြုမည်
                        divisions: 25,
                        label: "${durationSeconds.toInt} s",
                        onChanged: (val) {
                          setDialogState(() {
                            durationSeconds = val;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isMm ? "မလုပ်တော့ပါ" : "Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(isMm ? "အတည်ပြုမည်" : "Confirm"),
                    ),
                  ],
                );
              },
            );
          },
        );

        setState(() {
          _selectedAudio = audioFile;
          _audioStartSecond = startSecond;
          // လိုအပ်ပါက durationSeconds ကိုပါ variable အနေဖြင့် သိမ်းဆည်းနိုင်ပါသည်
        });
      }
    } catch (e) {
      print("Audio Picker Error: $e");
    }
  }

// 🌟 ရွေးချယ်ထားသော သီချင်းကို Preview နားထောင်ရန် (၂၀ စက္ကန့်စာ)
// ignore: unused_element
  Future<void> _toggleAudioPreview() async {
    if (_selectedAudio == null) return;

    try {
      if (_isPlayingAudio) {
        await _audioPlayer.pause();
        setState(() {
          _isPlayingAudio = false;
        });
      } else {
        // သီချင်းကို စတင်မည့်နေရာကနေ ဖွင့်မည်
        final urlSource = DeviceFileSource(_selectedAudio!.path);
        await _audioPlayer.play(urlSource);
        await _audioPlayer.seek(Duration(seconds: _audioStartSecond.toInt()));

        setState(() {
          _isPlayingAudio = true;
        });

        // စက္ကန့် ၂၀ ပြည့်လျှင် အလိုအလျောက် ရပ်သွားစေရန်
        Future.delayed(const Duration(seconds: 20), () async {
          if (_isPlayingAudio) {
            await _audioPlayer.pause();
            if (mounted) {
              setState(() {
                _isPlayingAudio = false;
              });
            }
          }
        });
      }
    } catch (e) {
      print("Audio Preview Error: $e");
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    bool isMm = isMyanmarNotifier.value;

    final picker = ImagePicker();
    final pickedFile = isVideo
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);

    if (pickedFile != null) {
      File file = File(pickedFile.path);

      if (isVideo) {
        try {
          MediaInfo? mediaInfo = await VideoCompress.getMediaInfo(file.path);
          // 🌟 ၃ မိနစ် (180,000 milliseconds) ထက် ကျော်လွန်ပါက တားမြစ်မည်
          if (mediaInfo.duration != null && mediaInfo.duration! > 180000) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isMm
                      ? "ဗီဒီယိုသည် ၃ မိနစ် (စက္ကန့် ၁၈၀) ထက် မကျော်ရပါ။"
                      : "Video must not exceed 3 minutes (180 seconds).",
                ),
              ),
            );
            return;
          }
        } catch (e) {
          print("Media Info Error: $e");
        }

        String? thumbPath;
        try {
          final thumbnailFile = await VideoCompress.getFileThumbnail(
            file.path,
            quality: 50,
            position: -1,
          );
          thumbPath = thumbnailFile.path;
        } catch (e) {
          print("VideoCompress Thumbnail Error: $e");
        }

        setState(() {
          _selectedImages.clear();
          _selectedVideo = file;
          _videoThumbnailPath = thumbPath;
          _isVideo = true;
        });
      } else {
        setState(() {
          _selectedImages
              .add(XFile(pickedFile.path)); // 👈 XFile အဖြစ် အတိအကျ ထည့်ပေးပါ
        });
      }
    }
  }

  void _showMediaSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: SafeArea(
            bottom: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 20, 10, 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: isMyanmarNotifier,
                builder: (context, isMm, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        isMm ? "မီဒီယာ ဖိုင်ရယူရန်" : "Select Media Type",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        leading: const Icon(Icons.photo_library,
                            color: Colors.blueAccent),
                        title: Text(
                          isMm
                              ? "ဂယ်လီယာမှ ပုံများ ရွေးမည်"
                              : "Pick Images from Gallery",
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickMultipleImages();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.video_library,
                            color: Colors.orange),
                        title: Text(
                          isMm
                              ? "ဂယ်လီယာမှ ဗီဒီယိုရွေးမည် (၃ မိနစ်စာ)"
                              : "Pick Video (Max 3 Min)",
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickMedia(ImageSource.gallery, isVideo: true);
                        },
                      ),
                      // 🌟 သီချင်းထည့်ရန် Option
                      ListTile(
                        leading: const Icon(Icons.audiotrack,
                            color: Colors.purpleAccent),
                        title: Text(
                          isMm
                              ? "သီချင်း (Audio) ထည့်မည်"
                              : "Add Background Music",
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickAudio();
                        },
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.camera_alt, color: Colors.green),
                        title: Text(
                          isMm
                              ? "ကင်မရာဖြင့် ပုံရိုက်မည်"
                              : "Take Photo with Camera",
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _pickMedia(ImageSource.camera, isVideo: false);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    bool isMm = isMyanmarNotifier.value;

    if (_textController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedVideo == null &&
        _selectedAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? "ကျေးဇူးပြု၍ စာ သို့မဟုတ် ပုံ/ဗီဒီယို/သီချင်း ထည့်ပါ။"
                : "Please add text or media.",
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isCancelled = false;
      _uploadProgress = 0.0;
      _progressText = "0%";
    });

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogStateSetter = setDialogState;
            return ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.4)
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.white.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor:
                                  isDark ? Colors.white24 : Colors.black12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blueAccent),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              isMm
                                  ? "ပို့စ်ကို တင်နေပါသည်... ($_progressText)\nကျေးဇူးပြု၍ ခဏစောင့်ဆိုင်းပေးပါ။"
                                  : "Posting... ($_progressText)\nPlease wait a moment.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isCancelled = true;
                                  _isLoading = false;
                                });
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                isMm ? "ပယ်ဖျက်မည် (Cancel)" : "Cancel",
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
    );

    try {
      List<String> mediaUrls = [];
      String singleMediaUrl = '';
      String audioUrl = '';

      int totalItems = _selectedImages.length +
          (_selectedVideo != null ? 1 : 0) +
          (_selectedAudio != null ? 1 : 0);
      int currentIndex = 0;

      // 1. ပုံများ Upload တင်ခြင်း
      if (_selectedImages.isNotEmpty) {
        for (var imageFile in _selectedImages) {
          if (_isCancelled) return;

          // 🌟 XFile ကို တိုက်ရိုက် ပေးလိုက်ပါ (Web ရော Mobile ပါ အဆင်ပြေပါပြီ)
          String? url = await R2Service.uploadFile(imageFile, 'posts_media');

          if (url != null) mediaUrls.add(url);
          currentIndex++;
          if (dialogStateSetter != null) {
            dialogStateSetter!(() {
              _uploadProgress = currentIndex / totalItems;
              _progressText = "${(_uploadProgress * 100).toInt()}%";
            });
          }
        }
      }

      // 2. ဗီဒီယို Upload တင်ခြင်း
      if (_selectedVideo != null && _isVideo) {
        if (_isCancelled) return;
        String? uploadedVideoUrl =
            await R2Service.uploadFile(_selectedVideo!, 'posts_media');
        if (uploadedVideoUrl != null) {
          singleMediaUrl = uploadedVideoUrl;
          mediaUrls.add(uploadedVideoUrl);
        }
        currentIndex++;
        if (dialogStateSetter != null) {
          dialogStateSetter!(() {
            _uploadProgress = currentIndex / totalItems;
            _progressText = "${(_uploadProgress * 100).toInt()}%";
          });
        }
      }

      // 3. သီချင်း (Audio) Upload တင်ခြင်း
      // 3. သီချင်း (Audio) Upload တင်ခြင်း
      if (_selectedAudio != null) {
        if (_isCancelled) return;

        // 🌟 Web ဖြစ်စေ Mobile ဖြစ်စေ File object ကို R2Service သို့ ပို့၍ Upload တင်ခြင်း
        String? uploadedAudioUrl =
            await R2Service.uploadFile(_selectedAudio!, 'posts_audio');

        if (uploadedAudioUrl != null) {
          audioUrl = uploadedAudioUrl;
        }

        currentIndex++;
        if (dialogStateSetter != null) {
          dialogStateSetter!(() {
            _uploadProgress = currentIndex / totalItems;
            _progressText = "${(_uploadProgress * 100).toInt()}%";
          });
        }
      }
      String uid = FirebaseAuth.instance.currentUser!.uid;
      User? currentUser = FirebaseAuth.instance.currentUser;
      String userName =
          currentUser?.displayName ?? (isMm ? "အသုံးပြုသူ" : "User");

      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      String userImage = '';
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          userImage = data['profileImageUrl'] ??
              data['profileImage'] ??
              data['photoURL'] ??
              currentUser?.photoURL ??
              '';
        }
      }

      final RegExp hashtagRegExp = RegExp(r'\B#\w+[\w_-]*');
      List<String> extractedHashtags = hashtagRegExp
          .allMatches(_textController.text)
          .map((match) => match.group(0)!.toLowerCase())
          .toSet()
          .toList();

      // Firestore တွင် Post အချက်အလက်များနှင့်အတူ audioUrl ပါ သိမ်းဆည်းမည်
      await FirebaseFirestore.instance.collection('posts').add({
        'uid': uid,
        'userName': userName,
        'userImage': userImage,
        'text': _textController.text.trim(),
        'mediaUrls': mediaUrls,
        'mediaUrl': singleMediaUrl.isNotEmpty
            ? singleMediaUrl
            : (mediaUrls.isNotEmpty ? mediaUrls.first : ''),
        'audioUrl': audioUrl, // 🌟 သီချင်းလင့်ခ် သိမ်းရန်
        '_audioStartSecond': _audioStartSecond,
        'likes': [],
        'viewedUserIds': [],
        'taggedUserIds': _taggedUserIds,
        'hashtags': extractedHashtags,
        'createdAt': FieldValue.serverTimestamp(),
        'isGolden': false,
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'viewCount': 0,
      });

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();

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
                isMm ? 'ပို့စ်အသစ် ဖန်တီးရန်' : 'Create New Post',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              );
            },
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return _isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      )
                    : TextButton(
                        onPressed: _submitPost,
                        child: Text(
                          isMm ? "တင်မည်" : "Post",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String displayName =
                      isMyanmarNotifier.value ? "အသုံးပြုသူ" : "User";
                  String? profileImg;
                  String role = 'member';

                  if (snapshot.hasData && snapshot.data!.exists) {
                    var data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null) {
                      displayName = data['displayName'] ??
                          data['name'] ??
                          data['userName'] ??
                          displayName;
                      profileImg = data['profileImageUrl'] ??
                          data['profileImage'] ??
                          data['photoURL'];
                      role = data['role'] ?? 'member';
                    }
                  }

                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage:
                            (profileImg != null && profileImg.isNotEmpty)
                                ? NetworkImage(profileImg)
                                : null,
                        child: (profileImg == null || profileImg.isEmpty)
                            ? const Icon(Icons.person, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: GoldenNameWidget(
                          name: displayName,
                          role: role,
                          fontSize: 16,
                          isWhiteBackground:
                              !isDark, // 🌟 Theme အလိုက် အရောင်ချိန်ရန်
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _textController,
                maxLines: 4,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: isMyanmarNotifier.value
                      ? "ယနေ့ သင့်ရဲ့ အတွေးအမြင်များကို ဝေမျှပါ..."
                      : "Share your thoughts today...",
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
// 🌟 1. Glass Hashtag Suggestion Box
              if (_showSuggestions && _suggestionType == 'hashtag')
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: _hashtagSuggestions.length,
                        itemBuilder: (context, index) {
                          String tag = _hashtagSuggestions[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              String currentText = _textController.text;
                              int lastHashIndex = currentText.lastIndexOf('#');
                              if (lastHashIndex != -1) {
                                String newText =
                                    "${currentText.substring(0, lastHashIndex)}$tag ";
                                _textController.text = newText;
                                _textController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _textController.text.length),
                                );
                              }
                              setState(() {
                                _showSuggestions = false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
// 🌟 2. Glass User Mention Suggestion Box
              if (_showUserSuggestions && _suggestionType == 'mention')
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: ListView.builder(
                        itemCount: _userSuggestions.length,
                        itemBuilder: (context, index) {
                          var user = _userSuggestions[index];
                          String userName = user['name'];
                          String? userImg = user['image'];
                          String userRole = user['role'] ?? 'member';

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  (userImg != null && userImg.isNotEmpty)
                                      ? NetworkImage(userImg)
                                      : null,
                              child: (userImg == null || userImg.isEmpty)
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: GoldenNameWidget(
                              name: userName,
                              role: userRole,
                              fontSize: 14,
                            ),
                            subtitle: Text(
                              "@$userName",
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              String currentText = _textController.text;
                              int lastAtIndex = currentText.lastIndexOf('@');
                              if (lastAtIndex != -1) {
                                String newText =
                                    "${currentText.substring(0, lastAtIndex)}@$userName ";
                                _textController.text = newText;
                                _textController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                      offset: _textController.text.length),
                                );

                                if (!_taggedUserIds.contains(user['uid'])) {
                                  _taggedUserIds.add(user['uid']);
                                }
                              }
                              setState(() {
                                _showUserSuggestions = false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              // 🌟 ရွေးချယ်ထားသော သီချင်း (Audio) နှင့် Trim လုပ်ထားသည့် အချက်အလက်ပြသရန်
              if (_selectedAudio != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purpleAccent),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.music_note, color: Colors.purpleAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedAudio!.path.split('/').last,
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMyanmarNotifier.value
                                  ? "စတင်မည့်နေရာ: ${_audioStartSecond.toInt()} စက္ကန့် (Trim ပြီး)"
                                  : "Start: ${_audioStartSecond.toInt()}s (Trimmed)",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.purple),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _selectedAudio = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // မီဒီယာ ရွေးချယ်မှုအပိုင်း နှင့် Preview ပြသခြင်း
              _selectedImages.isEmpty &&
                      _selectedVideo == null &&
                      _selectedAudio == null
                  ? InkWell(
                      onTap: () => _showMediaSourceActionSheet(context),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate,
                                size: 40, color: Colors.blueAccent),
                            const SizedBox(height: 8),
                            Text(
                              isMyanmarNotifier.value
                                  ? "ပုံ၊ ဗီဒီယို (၃မိနစ်စာ) သို့မဟုတ် သီချင်း ထည့်ရန်"
                                  : "Add Photo, Video (Max 3 Min) or Audio",
                              style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        // 🌟 ၁။ ပုံများ ရွေးချယ်ထားလျှင် Grid ပုံစံဖြင့် Preview ပြရန်
                        if (_selectedImages.isNotEmpty)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _selectedImages.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemBuilder: (context, index) {
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: kIsWeb
                                        ? FutureBuilder<Uint8List>(
                                            future: _selectedImages[index]
                                                .readAsBytes(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return const Center(
                                                  child:
                                                      CircularProgressIndicator());
                                            },
                                          )
                                        : Image.file(
                                            File(_selectedImages[index]
                                                .path), // 👈 ဤနေရာတွင် File(_selectedImages[index].path) ဟု ပြောင်းပေးပါ
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  // ပုံတစ်ပုံချင်းစီကို ဖျက်ချင်ရင် နှိပ်လို့ရမယ့် Close ခလုတ်
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                        // 🌟 ၂။ ဗီဒီယို ရွေးချယ်ထားလျှင် ပြရန်
                        if (_selectedVideo != null && _isVideo)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 220,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _videoThumbnailPath != null
                                      ? Image.file(
                                          File(_videoThumbnailPath!),
                                          fit: BoxFit.cover,
                                        )
                                      : const Center(
                                          child: Icon(Icons.videocam,
                                              size: 50, color: Colors.white70),
                                        ),
                                ),
                              ),
                              const Positioned.fill(
                                child: Center(
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    size: 60,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    child:
                                        Icon(Icons.close, color: Colors.white),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedVideo = null;
                                      _videoThumbnailPath = null;
                                      _isVideo = false;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showMediaSourceActionSheet(context),
                          icon: const Icon(Icons.add),
                          label: Text(isMyanmarNotifier.value
                              ? "မီဒီယာ ဖိုင်များ ထပ်ထည့်ရန်"
                              : "Add More Media"),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Edit Post Page (With Video Compression & Progress Bar Status Loading Dialog)
// -------------------------------------------------------------
class EditPostPage extends StatefulWidget {
  final String postId;
  final String currentText;
  final String? currentMediaUrl;
  final List<dynamic>? currentMediaUrls;

  const EditPostPage({
    super.key,
    required this.postId,
    required this.currentText,
    this.currentMediaUrl,
    this.currentMediaUrls,
  });

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late TextEditingController _textController;

  List<File> _newSelectedFiles = [];
  File? _selectedVideoFile;
  File? _videoThumbnailFile;

  // 🌟 Progress Status အတွက် လိုအပ်သော Variables များ ထည့်သွင်းခြင်း
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  String _progressText = "0%";
  bool _isCancelled = false;
  StateSetter? dialogStateSetter;

  bool _removeAllExistingMedia = false;
  late List<dynamic> _activeMediaUrls;

  // Mention & Hashtag Suggestion အတွက် Variables များ
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _showUserSuggestions = false;
  final List<String> _taggedUserIds = [];

  List<String> _hashtagSuggestions = [];
  bool _showHashtagSuggestions = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentText);
    _textController.addListener(_onTextChanged);

    _activeMediaUrls = widget.currentMediaUrls != null
        ? List.from(widget.currentMediaUrls!)
        : (widget.currentMediaUrl != null && widget.currentMediaUrl!.isNotEmpty
            ? [widget.currentMediaUrl!]
            : []);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // @mention နှင့် #hashtag ရေးသည့်အခါ စောင့်ကြည့် ရှာဖွေမည့် Logic
  void _onTextChanged() async {
    final text = _textController.text;
    final selection = _textController.selection;

    if (selection.baseOffset > 0 && selection.baseOffset <= text.length) {
      final subText = text.substring(0, selection.baseOffset);

      final lastAtIndex = subText.lastIndexOf('@');
      final lastHashIndex = subText.lastIndexOf('#');

      if (lastAtIndex != -1 && lastAtIndex > lastHashIndex) {
        final query = subText.substring(lastAtIndex + 1);
        if (!query.contains(' ')) {
          await _fetchUserSuggestions(query);
          return;
        }
      } else if (lastHashIndex != -1 && lastHashIndex > lastAtIndex) {
        final query = subText.substring(lastHashIndex + 1);
        if (!query.contains(' ')) {
          await _fetchHashtagSuggestions(query);
          return;
        }
      }
    }
    setState(() {
      _showUserSuggestions = false;
      _showHashtagSuggestions = false;
    });
  }

  // Firebase မှ Users များကို Query ထုတ်ရန်
  Future<void> _fetchUserSuggestions(String query) async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      List<Map<String, dynamic>> matchedUsers = [];
      String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (doc.id == currentUid) continue;

        String name = (data['userName'] ??
                data['name'] ??
                data['fullName'] ??
                data['displayName'] ??
                '')
            .toString();

        if (name.toLowerCase().contains(query.toLowerCase())) {
          matchedUsers.add({
            'uid': doc.id,
            'name': name,
            'image': data['profileImageUrl'] ??
                data['profileImage'] ??
                data['photoURL'] ??
                '',
          });
        }
      }

      setState(() {
        _userSuggestions = matchedUsers;
        _showUserSuggestions = _userSuggestions.isNotEmpty;
        _showHashtagSuggestions = false;
      });
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  // Firestore မှ Hashtag များကို Query ထုတ်ရန်
  Future<void> _fetchHashtagSuggestions(String query) async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('posts').get();
      Set<String> matchedHashtags = {};

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('hashtags') && data['hashtags'] is List) {
          List tags = data['hashtags'];
          for (var tag in tags) {
            String tagStr = tag.toString();
            String cleanTag =
                tagStr.startsWith('#') ? tagStr.substring(1) : tagStr;
            if (cleanTag.toLowerCase().contains(query.toLowerCase())) {
              matchedHashtags.add(cleanTag);
            }
          }
        }
      }

      setState(() {
        _hashtagSuggestions = matchedHashtags.toList();
        _showHashtagSuggestions = _hashtagSuggestions.isNotEmpty;
        _showUserSuggestions = false;
      });
    } catch (e) {
      print("Error fetching hashtags: $e");
    }
  }

  // Suggestion ထဲက User ကို နှိပ်လိုက်သည့်အခါ
  void _selectUser(Map<String, dynamic> user) {
    final text = _textController.text;
    final selection = _textController.selection;
    final subText = text.substring(0, selection.baseOffset);
    final lastAtIndex = subText.lastIndexOf('@');

    if (lastAtIndex == -1) return;

    final afterCursor = text.substring(selection.baseOffset);
    String userName = user['name'];

    final newText = "${text.substring(0, lastAtIndex)}@$userName $afterCursor";

    _textController.text = newText;
    _textController.selection =
        TextSelection.collapsed(offset: lastAtIndex + userName.length + 2);

    if (!_taggedUserIds.contains(user['uid'])) {
      _taggedUserIds.add(user['uid']);
    }

    setState(() {
      _showUserSuggestions = false;
    });
  }

  // Suggestion ထဲက Hashtag ကို နှိပ်လိုက်သည့်အခါ
  void _selectHashtag(String tag) {
    final text = _textController.text;
    final selection = _textController.selection;
    final subText = text.substring(0, selection.baseOffset);
    final lastHashIndex = subText.lastIndexOf('#');

    if (lastHashIndex == -1) return;

    final afterCursor = text.substring(selection.baseOffset);
    final newText = "${text.substring(0, lastHashIndex)}#$tag $afterCursor";

    _textController.text = newText;
    _textController.selection =
        TextSelection.collapsed(offset: lastHashIndex + tag.length + 2);

    setState(() {
      _showHashtagSuggestions = false;
    });
  }

  bool _isImageUrl(String url) {
    final lowercase = url.toLowerCase();
    return lowercase.contains('.jpg') ||
        lowercase.contains('.jpeg') ||
        lowercase.contains('.png') ||
        lowercase.contains('.webp') ||
        (!lowercase.contains('.mp4') &&
            !lowercase.contains('.mov') &&
            !lowercase.contains('.avi'));
  }

  Future<void> _pickMedia(bool isVideo) async {
    final picker = ImagePicker();
    if (isVideo) {
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile != null) {
        Uint8List? thumbBytes = await VideoThumbnail.thumbnailData(
          video: pickedFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 500,
          quality: 75,
        );

        File? thumbFile;
        if (thumbBytes != null) {
          final tempDir = await getTemporaryDirectory();
          thumbFile = File(
              '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
          await thumbFile.writeAsBytes(thumbBytes);
        }

        setState(() {
          _selectedVideoFile = File(pickedFile.path);
          _videoThumbnailFile = thumbFile;
          _newSelectedFiles.clear();
          _activeMediaUrls.clear();
          _removeAllExistingMedia = true;
        });
      }
    } else {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newSelectedFiles = pickedFiles.map((e) => File(e.path)).toList();
          _selectedVideoFile = null;
          _videoThumbnailFile = null;
          _activeMediaUrls.clear();
          _removeAllExistingMedia = true;
        });
      }
    }
  }

  // 🌟 ပို့စ်သိမ်းဆည်းခြင်း (CreatePost ကဲ့သို့ Progress Dialog ဖြင့် % နှုန်းများ အမှန်တကယ် ပြသရန်)
  // 🌟 ပို့စ်ပြင်ဆင်သိမ်းဆည်းခြင်း (CreatePost ကဲ့သို့ Progress Dialog နှင့် % နှုန်းများ အမှန်တကယ် ပြသရန်)
  Future<void> _updatePost() async {
    setState(() {
      _isLoading = true;
      _isCancelled = false;
      _uploadProgress = 0.0;
      _progressText = "0%";
    });

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogStateSetter = setDialogState;
            return ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Dialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.4)
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.white.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LinearProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor:
                                  isDark ? Colors.white24 : Colors.black12,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blueAccent),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              isMm
                                  ? "ပို့စ်ကို ပြင်ဆင်နေပါသည်... ($_progressText)\nကျေးဇူးပြု၍ ခဏစောင့်ဆိုင်းပေးပါ။"
                                  : "Editing post... ($_progressText)\nPlease wait a moment.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isCancelled = true;
                                  _isLoading = false;
                                });
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                isMm ? "Cancel (ပယ်ဖျက်မည်)" : "Cancel",
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
    );

    try {
      // 🌟 လက်ရှိ Language ကို စစ်ဆေးရန် (True ဆိုရင် မြန်မာ၊ False ဆိုရင် English)
      bool isMm = isMyanmarNotifier.value;

      List<String> finalMediaUrls = [];

      if (!_removeAllExistingMedia) {
        finalMediaUrls = _activeMediaUrls.map((e) => e.toString()).toList();
      }

      int totalItems =
          _newSelectedFiles.length + (_selectedVideoFile != null ? 1 : 0);
      int currentIndex = 0;

      // 🌟 ပုံအသစ်များ တင်ခြင်းနှင့် Progress Update လုပ်ခြင်း
      if (_newSelectedFiles.isNotEmpty) {
        for (var file in _newSelectedFiles) {
          if (_isCancelled) return;

          double startProgress =
              totalItems > 0 ? currentIndex / totalItems : 0.0;
          if (dialogStateSetter != null) {
            dialogStateSetter!(() {
              _uploadProgress = startProgress;
              _progressText = "${(_uploadProgress * 100).toInt()}%";
            });
          }

          String? uploadedUrl = await R2Service.uploadFile(file, 'posts_media');
          if (_isCancelled) return;

          if (uploadedUrl != null) {
            finalMediaUrls.add(uploadedUrl);
          }

          currentIndex++;
          _uploadProgress = totalItems > 0 ? currentIndex / totalItems : 1.0;
          int percentInt = (_uploadProgress * 100).toInt();

          if (dialogStateSetter != null) {
            dialogStateSetter!(() {
              _uploadProgress = currentIndex / totalItems;
              _progressText = "$percentInt%";
            });
          }
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // 🌟 ဗီဒီယိုအသစ် တင်ခြင်း (Create Post ကဲ့သို့ Compression ပါဝင်သည်)
      if (_selectedVideoFile != null) {
        if (_isCancelled) return;
        File fileToUpload = _selectedVideoFile!;

        // 🌟 Web မဟုတ်မှသာ (Mobile ဖြစ်မှသာ) Video Compress လုပ်ရန်
        if (!kIsWeb) {
          var subscription =
              VideoCompress.compressProgress$.subscribe((progress) {
            if (dialogStateSetter != null) {
              dialogStateSetter!(() {
                double percent = progress > 1 ? progress / 100 : progress;
                _progressText = isMm
                    ? "ဗီဒီယို ပြင်ဆင်နေပါသည်... ${(percent * 100).toStringAsFixed(0)}%"
                    : "Compressing video... ${(percent * 100).toStringAsFixed(0)}%";
              });
            }
          });

          try {
            final compressedVideo = await VideoCompress.compressVideo(
              _selectedVideoFile!.path,
              quality: VideoQuality.MediumQuality,
              deleteOrigin: false,
            );

            subscription.unsubscribe();

            if (compressedVideo != null && compressedVideo.file != null) {
              fileToUpload = compressedVideo.file!;
            }
          } catch (e) {
            subscription.unsubscribe();
            print("Video Compression Error: $e");
          }
        }

        if (_isCancelled) return;

        if (dialogStateSetter != null) {
          dialogStateSetter!(() {
            _progressText =
                isMm ? "ဗီဒီယို တင်နေပါပြီ..." : "Uploading video...";
          });
        }

        String? uploadedVideoUrl =
            await R2Service.uploadFile(fileToUpload, 'posts_media');

        if (_isCancelled) return;

        if (uploadedVideoUrl != null) {
          finalMediaUrls.clear();
          finalMediaUrls.add(uploadedVideoUrl);
        }

        currentIndex++;
        _uploadProgress = 1.0;
        if (dialogStateSetter != null) {
          dialogStateSetter!(() {
            _uploadProgress = 1.0;
            _progressText = "100%";
          });
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
      final RegExp hashtagRegExp = RegExp(r'\B#\w+[\w_-]*');
      List<String> updatedHashtags = hashtagRegExp
          .allMatches(_textController.text)
          .map((match) => match.group(0)!.toLowerCase())
          .toSet()
          .toList();

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
        'text': _textController.text.trim(),
        'mediaUrls': finalMediaUrls,
        'mediaUrl': finalMediaUrls.isNotEmpty ? finalMediaUrls[0] : '',
        'hashtags': updatedHashtags,
        'taggedUserIds': FieldValue.arrayUnion(_taggedUserIds),
      });

      if (!mounted) return;
      Navigator.pop(context); // Dialog ပိတ်ရန်
      Navigator.pop(context); // Page မှထွက်ရန်
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dialog ပိတ်ရန်
      bool isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? "ပြင်ဆင်၍မအောင်မြင်ပါ။ Error: $e"
                : "Failed to update. Error: $e",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDarkMode = themeProvider.currentTheme != 'Default';
    Color textColor = themeProvider.getTextColor();

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return Text(
                isMm ? 'ပို့စ်ပြင်ဆင်ရန်' : 'Edit Post',
                style: TextStyle(color: textColor),
              );
            },
          ),
          iconTheme: IconThemeData(color: textColor),
          actions: [
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  )
                : ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return TextButton(
                        onPressed: _updatePost,
                        child: Text(
                          isMm ? "သိမ်းမည်" : "Save",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.blueAccent : Colors.blue,
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Glassmorphism Suggestions Box
              if (_showUserSuggestions || _showHashtagSuggestions)
                Container(
                  height: 140,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.black.withOpacity(0.4)
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.2)
                                : Colors.white.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: ListView.builder(
                          itemCount: _showUserSuggestions
                              ? _userSuggestions.length
                              : _hashtagSuggestions.length,
                          itemBuilder: (context, index) {
                            if (_showUserSuggestions) {
                              var user = _userSuggestions[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: user['image'].isNotEmpty
                                      ? NetworkImage(user['image'])
                                      : null,
                                  child: user['image'].isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(user['name'],
                                    style: TextStyle(color: textColor)),
                                onTap: () => _selectUser(user),
                              );
                            } else {
                              var tag = _hashtagSuggestions[index];
                              return ListTile(
                                leading: const Icon(Icons.tag,
                                    color: Colors.blueAccent),
                                title: Text("#$tag",
                                    style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold)),
                                onTap: () => _selectHashtag(tag),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),

              ValueListenableBuilder<bool>(
                valueListenable: isMyanmarNotifier,
                builder: (context, isMm, child) {
                  return TextField(
                    controller: _textController,
                    maxLines: 4,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: isMm
                          ? "စာသားများကို ပြင်ဆင်ပါ (#hashtag, @mention)..."
                          : "Edit text (#hashtag, @mention)...",
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      filled: true,
                      fillColor: isDarkMode
                          ? const Color(0xFF1E1E1E).withOpacity(0.8)
                          : Colors.white.withOpacity(0.9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDarkMode ? Colors.blueAccent : Colors.blue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Preview Section
              if (_selectedVideoFile != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _videoThumbnailFile != null
                          ? Image.file(
                              _videoThumbnailFile!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 220,
                              width: double.infinity,
                              color: Colors.black,
                              child: const Center(
                                  child: Icon(Icons.videocam,
                                      size: 50, color: Colors.white)),
                            ),
                    ),
                    const Positioned.fill(
                      child: Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 50,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedVideoFile = null;
                            _videoThumbnailFile = null;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_newSelectedFiles.isNotEmpty) ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _newSelectedFiles.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: kIsWeb
                                ? FutureBuilder<Uint8List>(
                                    future:
                                        _newSelectedFiles[index].readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Image.memory(snapshot.data!,
                                            height: 220,
                                            width: double.infinity,
                                            fit: BoxFit.cover);
                                      }
                                      return const SizedBox(
                                          height: 220,
                                          child: Center(
                                              child:
                                                  CircularProgressIndicator()));
                                    },
                                  )
                                : Image.file(
                                    _newSelectedFiles[index],
                                    height: 220,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _newSelectedFiles.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else if (_activeMediaUrls.isNotEmpty &&
                  !_removeAllExistingMedia) ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activeMediaUrls.length,
                  itemBuilder: (context, index) {
                    String url = _activeMediaUrls[index].toString();
                    bool isVideo = !_isImageUrl(url);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              height: 220,
                              width: double.infinity,
                              child: isVideo
                                  ? PostVideoPlayer(
                                      videoUrl: url,
                                      userName: '',
                                      uid: '',
                                      postId: '',
                                      role: null,
                                    )
                                  : Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _activeMediaUrls.removeAt(index);
                                  if (_activeMediaUrls.isEmpty) {
                                    _removeAllExistingMedia = true;
                                  }
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: isMyanmarNotifier,
                builder: (context, isMm, child) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _pickMedia(false),
                        icon:
                            const Icon(Icons.photo_library, color: Colors.blue),
                        label: Text(
                            isMm ? "ဓာတ်ပုံများ ရွေးမည်" : "Select Photos"),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _pickMedia(true),
                        icon: const Icon(Icons.videocam, color: Colors.orange),
                        label: Text(isMm ? "ဗီဒီယို ရွေးမည်" : "Select Video"),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HashtagLinkifier extends Linkifier {
  const HashtagLinkifier();

  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    final list = <LinkifyElement>[];
    for (var element in elements) {
      if (element is TextElement) {
        final regexp = RegExp(r"\B#[\w\u0080-\uFFFF]+");
        final matches = regexp.allMatches(element.text);

        int index = 0;
        for (final match in matches) {
          if (match.start > index) {
            list.add(TextElement(element.text.substring(index, match.start)));
          }
          final hashtag = match.group(0)!;
          list.add(
              LinkableElement(hashtag, hashtag)); // Hashtag အဖြစ် သတ်မှတ်ခြင်း
          index = match.end;
        }
        if (index < element.text.length) {
          list.add(TextElement(element.text.substring(index)));
        }
      } else {
        list.add(element);
      }
    }
    return list;
  }
}

// 🌟 Mention များကို Link အဖြစ် ဖမ်းယူပေးမည့် Linkifier
class MentionLinkifier extends Linkifier {
  const MentionLinkifier();

  @override
  List<LinkifyElement> parse(
      List<LinkifyElement> elements, LinkifyOptions options) {
    final list = <LinkifyElement>[];
    for (var element in elements) {
      if (element is TextElement) {
        // @ နှင့်အတူ စာလုံးများကို ဖမ်းယူရန် RegEx
        final regexp = RegExp(r'\B@[\w\u1000-\u109F\.]+');
        final matches = regexp.allMatches(element.text);

        int index = 0;
        for (final match in matches) {
          if (match.start > index) {
            list.add(TextElement(element.text.substring(index, match.start)));
          }
          final mention = match.group(0)!;
          list.add(LinkableElement(mention, mention));
          index = match.end;
        }
        if (index < element.text.length) {
          list.add(TextElement(element.text.substring(index)));
        }
      } else {
        list.add(element);
      }
    }
    return list;
  }
}

// -------------------------------------------------------------
// Post Audio Player Widget (Autoplay & Minimalist Design with Visibility Detector)
// -------------------------------------------------------------
class PostAudioPlayer extends StatefulWidget {
  final String audioUrl;
  const PostAudioPlayer({super.key, required this.audioUrl});

  @override
  State<PostAudioPlayer> createState() => _PostAudioPlayerState();
}

class _PostAudioPlayerState extends State<PostAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  final bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ဖွင့်/ပိတ် လုပ်မည့် Function
  void _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      print("Audio Play Error: $e");
    }
  }

  // Viewport ထဲ ရောက်လာ/မရောက်လာ အလိုအလျောက် စစ်မည့် Function (Autoplay / Autostop)
  void _handleVisibilityChanged(double visibilityFraction) async {
    try {
      if (visibilityFraction > 0.5) {
        // Post က မျက်နှာပြင်ပေါ် ၅၀% ကျော် ရောက်လာရင် အလိုအလျောက် စဖွင့်မည်
        if (!_isPlaying) {
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        }
      } else {
        // Post က မျက်နှာပြင်ပေါ်ကနေ ကျော်သွားရင် (မမြင်ရတော့ရင်) အလိုအလျောက် ရပ်မည်
        if (_isPlaying) {
          await _audioPlayer.pause();
        }
      }
    } catch (e) {
      print("Visibility Audio Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // VisibilityDetector ကို အသုံးပြုရန် package လိုအပ်ပါသည် (visibility_detector: ^0.4.0+2)
    return VisibilityDetector(
      key: Key(widget.audioUrl),
      onVisibilityChanged: (visibilityInfo) {
        _handleVisibilityChanged(visibilityInfo.visibleFraction);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.shade200, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _togglePlay,
              child: Icon(
                _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: Colors.purpleAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.audiotrack, size: 14, color: Colors.purple),
            const SizedBox(width: 4),
            const Text(
              "Audio",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
