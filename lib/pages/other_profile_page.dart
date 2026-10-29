// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:io';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:karma/main.dart';
import 'package:karma/pages/chat_page.dart' hide NavigationHelper;
import 'package:karma/pages/search_page.dart';
import 'package:karma/pages/user_list_page.dart';
import 'package:karma/services/notification_service.dart';
import 'package:karma/utilis/navigation_helper.dart';
import 'package:karma/widgets/full_screen_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class OtherProfilePage extends StatefulWidget {
  final String userId;
  final String userName;

  const OtherProfilePage(
      {super.key, required this.userId, required this.userName});

  @override
  State<OtherProfilePage> createState() => _OtherProfilePageState();
}

class _OtherProfilePageState extends State<OtherProfilePage>
    with SingleTickerProviderStateMixin {
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  String? userAvatar;

  bool isFollowing = false;
  bool _isFollowLoading = false;
  late TabController _tabController;
  bool get _isDarkTheme =>
      Provider.of<ThemeProvider>(context).currentTheme != 'Default';

  Color get _cardBgColor {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (themeProvider.currentTheme == 'Default') {
      return Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      return Colors.white.withOpacity(0.15);
    } else {
      return Colors.black.withOpacity(0.3);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkIfFollowing();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInterstitialAd() async {
    InterstitialAd.load(
      adUnitId:
          'ca-app-pub-8755843731256088/3526033189', // Replace with your ad unit ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          print('Failed to load interstitial ad: $error');
        },
      ),
    );
  }

  Future<void> _checkIfFollowing() async {
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    if (userDoc.exists && userDoc.data()!.containsKey('following')) {
      setState(() {
        isFollowing = (userDoc['following'] as List).contains(widget.userId);
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return; // တစ်ကြိမ်ထက်ပိုမနှိပ်နိုင်အောင် တားဆီးရန်

    setState(() {
      _isFollowLoading = true;
    });

    try {
      String currentUid = FirebaseAuth.instance.currentUser!.uid;
      String currentUserName =
          FirebaseAuth.instance.currentUser?.displayName ?? "Unknown User";

      DocumentReference currentUserRef =
          FirebaseFirestore.instance.collection('users').doc(currentUid);
      DocumentReference targetUserRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);

      if (isFollowing) {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.update(currentUserRef, {
            'followingCount': FieldValue.increment(-1),
            'following': FieldValue.arrayRemove([widget.userId]),
          });
          transaction.update(targetUserRef, {
            'followersCount': FieldValue.increment(-1),
          });
        });
      } else {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          transaction.update(currentUserRef, {
            'followingCount': FieldValue.increment(1),
            'following': FieldValue.arrayUnion([widget.userId]),
          });
          transaction.update(targetUserRef, {
            'followersCount': FieldValue.increment(1),
          });
        });

        final isMm = isMyanmarNotifier.value;
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': widget.userId,
          'senderId': currentUid,
          'senderAvatar': FirebaseAuth.instance.currentUser?.photoURL ?? '',
          'message': isMm
              ? "$currentUserName started following you"
              : "$currentUserName started following you",
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        DocumentSnapshot receiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        if (receiverDoc.exists && receiverDoc['fcmToken'] != null) {
          final isMm = isMyanmarNotifier.value;
          NotificationService.sendNotification(
              receiverDoc['fcmToken'],
              isMm
                  ? "$currentUserName started following you"
                  : "$currentUserName started following you",
              isMm ? "Follower အသစ်!" : "New Follower!",
              'message');
        }
      }
      setState(() => isFollowing = !isFollowing);
    } catch (e) {
      // Error တစ်စုံတစ်ရာ ရှိခဲ့ရင် ဒီမှာ ဖမ်းနိုင်ပါတယ် (မလိုရင် ဖြုတ်ထားလည်းရပါတယ်)
      print("Follow error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isFollowLoading = false; // ပြီးသွားပါက ပြန်ဖွင့်ပေးရန်
        });
      }
    }
  }

  Future<void> _toggleLike(String postId, List likes, String ownerId) async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    var postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    String userName =
        FirebaseAuth.instance.currentUser?.displayName ?? "Unknown User";

    DocumentSnapshot senderDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    String senderAvatar = '';
    if (senderDoc.exists) {
      var data = senderDoc.data() as Map<String, dynamic>?;
      userName = data?['displayName'] ?? userName;
      senderAvatar = data?['profileImageUrl'] ??
          data?['profileImage'] ??
          data?['photoURL'] ??
          FirebaseAuth.instance.currentUser?.photoURL ??
          '';
    }

    // 🌟 Post ပိုင်ရှင်၏ Monetization Status ကို စစ်ဆေးရန်
    DocumentReference ownerRef =
        FirebaseFirestore.instance.collection('users').doc(ownerId);
    DocumentSnapshot ownerDoc = await ownerRef.get();
    bool isMonetized = false;
    if (ownerDoc.exists) {
      var ownerData = ownerDoc.data() as Map<String, dynamic>?;
      isMonetized = (ownerData?['monetizationStatus'] == 'approved');
    }

    if (likes.contains(uid)) {
      // Unlike လုပ်ခြင်း
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(postRef, {
          'likes': FieldValue.arrayRemove([uid]),
          'likesCount': FieldValue.increment(-1),
        });

        // Monetization အောင်ထားပါက Like ဖြုတ်လျှင် ၅၀ ကျပ် လျော့မည်
        if (isMonetized) {
          transaction.update(ownerRef, {
            'balance': FieldValue.increment(-50),
          });
        }
      });
    } else {
      // Like လုပ်ခြင်း
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(postRef, {
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

      if (uid != ownerId) {
        final isMm = isMyanmarNotifier.value;
        String msg = isMm
            ? "$userName က သင့် Post ကို Like ပေးသွားပါတယ်"
            : "$userName liked your post";

        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': ownerId,
          'senderId': uid,
          'senderAvatar': senderAvatar,
          'postId': postId,
          'message': msg,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (ownerDoc.exists && ownerDoc['fcmToken'] != null) {
          NotificationService.sendNotification(ownerDoc['fcmToken'], msg,
              isMm ? "Like အသစ်!" : "New Like!", 'message');
        }
      }
    }
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

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool isDark = (themeProvider.currentTheme != 'Default');

    Color modalBgColor;
    if (themeProvider.currentTheme == 'Default') {
      modalBgColor = Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      modalBgColor = const Color(0xFF1E1E1E).withOpacity(0.85);
    } else {
      modalBgColor = const Color(0xFF121212).withOpacity(0.85);
    }

    Color textColor = themeProvider.getTextColor();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalBgColor,
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
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
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

  Future<void> _processTip(BuildContext context, String senderId,
      String receiverId, num amount, String postId) async {
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount")),
      );
      return;
    }

    final senderRef =
        FirebaseFirestore.instance.collection('users').doc(senderId);
    final receiverRef =
        FirebaseFirestore.instance.collection('users').doc(receiverId);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final senderSnapshot = await transaction.get(senderRef);
        final senderData = senderSnapshot.data();
        final balance = (senderData?['balance'] as num?) ?? 0;

        if (balance < amount) {
          throw StateError('INSUFFICIENT_BALANCE');
        }

        transaction.update(senderRef, {'balance': balance - amount});
        transaction.set(
            receiverRef,
            {
              'balance': FieldValue.increment(amount),
            },
            SetOptions(merge: true));
        transaction.set(
            postRef,
            {
              'totalTips': FieldValue.increment(amount),
            },
            SetOptions(merge: true));
      });

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tip sent successfully")),
      );
    } catch (e) {
      if (!context.mounted) return;
      final message = e is StateError && e.message == 'INSUFFICIENT_BALANCE'
          ? "Insufficient balance"
          : "Failed to send tip";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  bool _isVideoUrl(String url) {
    final lowercase = url.toLowerCase();
    return lowercase.contains('.mp4') ||
        lowercase.contains('.mov') ||
        lowercase.contains('.webm') ||
        lowercase.contains('.mkv') ||
        lowercase.contains('.avi') ||
        lowercase.contains('video');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color cardColor = _cardBgColor;
    Color textColor = themeProvider.getTextColor();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            decoration: themeProvider.getBackgroundDecoration(),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: textColor),
                title:
                    Text(widget.userName, style: TextStyle(color: textColor)),
              ),
              body: const Center(child: CircularProgressIndicator()),
            ),
          );
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        String displayName = userData['displayName'] ?? widget.userName;
        String userRole = userData['role'] ?? 'member';
        List<dynamic> hobbies = userData['hobbies'] ?? [];

        return Container(
          decoration: themeProvider.getBackgroundDecoration(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              title: GoldenNameWidget(
                name: displayName,
                role: userRole,
                fontSize: 18,
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // 1. Profile Header Box
                      // 1. Profile Header Box
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.all(8.0),
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(isDark ? 0.2 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🌟 ဒီနေရာမှာ GestureDetector ထည့်ပါ
                                  GestureDetector(
                                    onTap: () {
                                      final String profileImageUrl =
                                          userData['profileImageUrl'] ?? "";
                                      if (profileImageUrl.isNotEmpty) {
                                        NavigationHelper.push(
                                          context,
                                          FullScreenGalleryScreen(
                                              mediaUrls: [profileImageUrl],
                                              initialIndex: 0),
                                        );
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                                isDark ? 0.3 : 0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Builder(
                                        builder: (context) {
                                          final String profileImageUrl =
                                              userData['profileImageUrl'] ?? "";
                                          return (profileImageUrl.isNotEmpty)
                                              ? ClipOval(
                                                  child: Image.network(
                                                    profileImageUrl,
                                                    width: 80,
                                                    height: 80,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Container(
                                                        width: 80,
                                                        height: 80,
                                                        color: Colors
                                                            .grey.shade300,
                                                        child: const Icon(
                                                            Icons.person,
                                                            color: Colors.grey),
                                                      );
                                                    },
                                                  ),
                                                )
                                              : const CircleAvatar(
                                                  radius: 40,
                                                  child: Icon(Icons.person),
                                                );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GoldenNameWidget(
                                          name: displayName,
                                          role: userRole,
                                          fontSize: 18,
                                        ),
                                        if (userData['username'] != null &&
                                            userData['username']
                                                .toString()
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '@${userData['username']}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                        if (isFollowing) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.grey[800]
                                                  : Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "Follows you",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.grey[300]
                                                    : Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (hobbies.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4.0,
                                            runSpacing: 4.0,
                                            children: hobbies.map((hobby) {
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.blue
                                                          .withOpacity(0.2)
                                                      : Colors.blue
                                                          .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.blue
                                                        .withOpacity(0.4),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Text(
                                                  hobby.toString(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: isDark
                                                        ? Colors.blueAccent[100]
                                                        : Colors.blue[800],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () => NavigationHelper.push(
                                            context,
                                            UserListPage(
                                              title: "Following",
                                              userId: widget.userId,
                                              isFollowers: false,
                                            ),
                                          ),
                                          child: _buildStatItem(
                                            '${userData['followingCount'] ?? 0}',
                                            'Following',
                                            isDark,
                                            textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: () => NavigationHelper.push(
                                            context,
                                            UserListPage(
                                              title: "Followers",
                                              userId: widget.userId,
                                              isFollowers: true,
                                            ),
                                          ),
                                          child: _buildStatItem(
                                            '${userData['followersCount'] ?? 0}',
                                            'Followers',
                                            isDark,
                                            textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isFollowLoading
                                          ? null
                                          : _toggleFollow, // 🌟 Loading ဖြစ်နေရင် ပိတ်ထားမည်
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isFollowing
                                            ? (isDark
                                                ? Colors.grey[800]
                                                : Colors.grey[300])
                                            : Colors.blue,
                                        foregroundColor: isFollowing
                                            ? (isDark
                                                ? Colors.white70
                                                : Colors.black87)
                                            : Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                      child: _isFollowLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ) // 🌟 Loading နေစဉ်စက်ဝိုင်းလေးပြမည်
                                          : Text(
                                              isFollowing
                                                  ? "Unfollow"
                                                  : "Follow",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => NavigationHelper.push(
                                        context,
                                        ChatPage(
                                          receiverId: widget.userId,
                                          receiverName: displayName,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                      child: ValueListenableBuilder<bool>(
                                        valueListenable: isMyanmarNotifier,
                                        builder: (context, isMm, child) {
                                          return Text(
                                            isMm ? "စာပို့မည်" : "Message",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isDarkTheme
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isDarkTheme
                                        ? Colors.white24
                                        : Colors.grey.withOpacity(0.2),
                                  ),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    String bioText =
                                        userData['bio'] ?? "No bio available.";
                                    final urlRegExp =
                                        RegExp(r'(https?:\/\/[^\s]+)');
                                    final match = urlRegExp.firstMatch(bioText);

                                    if (match != null) {
                                      String urlStr = match.group(0)!;
                                      int startIndex = bioText.indexOf(urlStr);
                                      String beforeText =
                                          bioText.substring(0, startIndex);
                                      String afterText = bioText.substring(
                                          startIndex + urlStr.length);

                                      return RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[300]
                                                : Colors.grey[700],
                                            fontSize: 14,
                                          ),
                                          children: [
                                            if (beforeText.isNotEmpty)
                                              TextSpan(text: beforeText),
                                            WidgetSpan(
                                              child: InkWell(
                                                onTap: () async {
                                                  final Uri url =
                                                      Uri.parse(urlStr);
                                                  if (await canLaunchUrl(url)) {
                                                    await launchUrl(url,
                                                        mode: LaunchMode
                                                            .externalApplication);
                                                  }
                                                },
                                                child: Text(
                                                  urlStr,
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (afterText.isNotEmpty)
                                              TextSpan(text: afterText),
                                          ],
                                        ),
                                      );
                                    } else {
                                      return Text(
                                        bioText,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 2. Persistent TabBar Header (CustomScrollView အောက်မှာ တိုက်ရိုက်ရှိရပါမယ်)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            labelColor: Colors.blueAccent,
                            unselectedLabelColor:
                                isDark ? Colors.grey[400] : Colors.grey[600],
                            indicatorColor: Colors.blueAccent,
                            tabs: const [
                              Tab(icon: Icon(Icons.grid_on), text: "Posts"),
                              Tab(
                                  icon: Icon(Icons.video_library),
                                  text: "Videos"),
                            ],
                          ),
                          cardColor,
                        ),
                      ),

                      // 3. TabBarView အတွက် Fill Remaining
                      SliverFillRemaining(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildUserPostsSliver(userData, themeProvider,
                                isDark, cardColor, textColor),
                            _buildUserVideosGrid(isDark, textColor),
                          ],
                        ),
                      ),
                    ],
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

  void _showAdAndDownload(String videoUrl, Map<String, dynamic> userData) {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          _navigateToDownload(videoUrl, userData);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
          _navigateToDownload(videoUrl, userData);
        },
      );
      _interstitialAd!.show();
    } else {
      _navigateToDownload(videoUrl, userData);
    }
  }

  // WebView သို့မဟုတ် Download စာမျက်နှာဆီ သွားမည့် Function
  // WebView သို့မဟုတ် Download စာမျက်နှာဆီ သွားမည့် Function
  void _navigateToDownload(String videoUrl, Map<String, dynamic> userData) {
    String avatarUrl = userData['profileImageUrl'] ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _VideoWebViewScreen(
          videoUrl: videoUrl,
          userName: widget.userName,
          profileImageUrl:
              avatarUrl, // 🌟 userData ထဲက ပုံလင့်ခ်ကို တိုက်ရိုက်ထည့်ပေးပါ
          uid: widget.userId,
          postId: '',
          role: null,
        ),
      ),
    );
  }

  Widget _buildUserVideosGrid(bool isDark, Color textColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var videoDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String? mediaUrl = data['mediaUrl'] ?? data['imageUrl'];
          List<dynamic> mediaUrls = data['mediaUrls'] ?? [];

          bool hasVideo = (mediaUrl != null && _isVideoUrl(mediaUrl)) ||
              mediaUrls.any((url) => _isVideoUrl(url.toString()));
          return hasVideo;
        }).toList();

        if (videoDocs.isEmpty) {
          return Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Text(
                  isMm ? "ဗီဒီယိုများ မရှိသေးပါ။" : "No videos available yet.",
                  style: TextStyle(color: textColor),
                );
              },
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 9 / 16,
          ),
          itemCount: videoDocs.length,
          itemBuilder: (context, index) {
            var post = videoDocs.length > index ? videoDocs[index] : null;
            if (post == null) return const SizedBox.shrink();
            var data = post.data() as Map<String, dynamic>;

            List<dynamic> rawUrls = data['mediaUrls'] ?? [];
            List<String> mediaUrls = rawUrls.map((e) => e.toString()).toList();
            String? mediaUrl = data['mediaUrl'] ?? data['imageUrl'];
            if (mediaUrls.isEmpty && mediaUrl != null && mediaUrl.isNotEmpty) {
              mediaUrls.add(mediaUrl);
            }
            String videoUrl = mediaUrls.isNotEmpty ? mediaUrls[0] : '';

            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.black,
                    insetPadding: EdgeInsets.zero,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: PostVideoPlayer(
                            videoUrl: videoUrl,
                            userName: data['userName'] ?? widget.userName,
                            profileImageUrl: data['userImage'] ??
                                data['profileImageUrl'] ??
                                '',
                            uid: data['uid'] ?? widget.userId,
                            postId: post.id,
                            role: data['role'] ?? 'member',
                          ),
                        ),
                        Positioned(
                          top: 40,
                          left: 16,
                          child: IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 28),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (videoUrl.isNotEmpty)
                      PostVideoPlayer(
                        videoUrl: videoUrl,
                        userName: data['userName'] ?? widget.userName,
                        profileImageUrl:
                            data['userImage'] ?? data['profileImageUrl'] ?? '',
                        uid: data['uid'] ?? widget.userId,
                        postId: post.id,
                        role: data['role'] ?? 'member',
                      ),
                    // ဘယ်ဘက်အောက်ထောင့်မှာ View Count ပြရန်
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        color: Colors.black54,
                        child: Row(
                          children: [
                            const Icon(Icons.remove_red_eye,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              "${data['viewCount'] ?? 0}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ညာဘက်အပေါ်ထောင့် (သို့မဟုတ် အောက်ထောင့်) မှာ Download ခလုတ်တင်ရန်
                    Positioned(
                      top: 4,
                      right: 4,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.download,
                              color: Colors.white, size: 18),
                          onPressed: () {
                            // Post ထဲမှာပါတဲ့ userImage ကို သုံးမယ် (သို့မဟုတ် userData ထဲက ယူမယ်)
                            Map<String, dynamic> tempUserData = {
                              'profileImageUrl': data['userImage'] ??
                                  data['profileImageUrl'] ??
                                  ''
                            };
                            _showAdAndDownload(videoUrl, tempUserData);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(
      String count, String label, bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildUserPostsSliver(
      Map<String, dynamic> userData,
      ThemeProvider themeProvider,
      bool isDark,
      Color cardColor,
      Color textColor) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }
        var docs = snapshot.data!.docs;
        docs.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;

          bool isPinnedA = dataA['isPinned'] ?? false;
          bool isPinnedB = dataB['isPinned'] ?? false;

          if (isPinnedA && !isPinnedB) {
            return -1;
          } else if (!isPinnedA && isPinnedB) {
            return 1;
          }

          var tA = dataA['createdAt'] as Timestamp?;
          var tB = dataB['createdAt'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var post = docs[index];
            var data = post.data() as Map<String, dynamic>;
            bool isPinned = data['isPinned'] ?? false;
            List likes = data['likes'] ?? [];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: cardColor,
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPinned)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            Icon(Icons.push_pin,
                                size: 14, color: Colors.orange),
                            SizedBox(width: 4),
                            Text(
                              "Pinned Post",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        String commentUid = data['uid'] ?? '';
                        if (commentUid.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OtherProfilePage(
                                userId: commentUid,
                                userName: '',
                              ),
                            ),
                          );
                        }
                      },
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            data['userImage'] ??
                                userData['profileImageUrl'] ??
                                "",
                          ),
                        ),
                        title: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(data['uid'])
                              .get(),
                          builder: (context, userSnapshot) {
                            String role = 'member';
                            if (userSnapshot.hasData &&
                                userSnapshot.data!.exists) {
                              var postUserData = userSnapshot.data!.data()
                                  as Map<String, dynamic>;
                              role = postUserData['role'] ?? 'member';
                            }

                            return GoldenNameWidget(
                              name: data['userName'] ??
                                  userData['displayName'] ??
                                  "Unknown User",
                              role: role,
                              fontSize: 14,
                            );
                          },
                        ),
                        subtitle: Text(
                          data['createdAt'] != null
                              ? (data['createdAt'] as Timestamp)
                                  .toDate()
                                  .toString()
                                  .substring(0, 16)
                              : "",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    if (data['text'] != null &&
                        data['text'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Builder(
                          builder: (context) {
                            String text = data['text'] ?? "";
                            return RichText(
                              text: TextSpan(
                                style:
                                    TextStyle(fontSize: 15, color: textColor),
                                children: _buildHashtagTextSpans(
                                    text, context, textColor),
                              ),
                            );
                          },
                        ),
                      ),
                    if (data['audioUrl'] != null &&
                        data['audioUrl'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 6.0),
                        child: PostAudioPlayer(audioUrl: data['audioUrl']),
                      ),
                    _buildMediaWidget(context, data),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            likes.contains(currentUid)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.red,
                            size: 22,
                          ),
                          onPressed: () =>
                              _toggleLike(post.id, likes, data['uid']),
                        ),
                        Text(
                          "${data['likesCount'] ?? 0}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            Icons.comment_outlined,
                            size: 22,
                            color: textColor,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: _CommentBottomSheet(
                                  postId: post.id,
                                  postOwnerId: data['uid'],
                                ),
                              ),
                            );
                          },
                        ),
                        Text(
                          "${data['commentsCount'] ?? 0}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            showTipModal(
                              context,
                              data['uid'],
                              data['userName'],
                              post.id,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department,
                                  color: Colors.orange, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                "${data['totalTips'] ?? 0}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (data['mediaUrl'] != null &&
                            (data['mediaUrl']
                                    .toString()
                                    .toLowerCase()
                                    .contains('.mp4') ||
                                data['mediaUrl']
                                    .toString()
                                    .toLowerCase()
                                    .contains('.mov') ||
                                data['mediaUrl']
                                    .toString()
                                    .toLowerCase()
                                    .contains('.webm') ||
                                data['mediaUrl']
                                    .toString()
                                    .toLowerCase()
                                    .contains('.mkv'))) ...[
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.remove_red_eye_outlined,
                                size: 18,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${data['viewCount'] ?? 0}",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<InlineSpan> _buildHashtagTextSpans(
      String text, BuildContext context, Color textColor) {
    final List<InlineSpan> spans = [];
    final RegExp regExp =
        RegExp(r'(https?:\/\/[^\s]+|#[a-zA-Z0-9_\u1000-\u109F]+)');
    int lastMatchEnd = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(color: textColor),
        ));
      }

      final String matchedString = match.group(0)!;

      if (matchedString.startsWith('http://') ||
          matchedString.startsWith('https://')) {
        spans.add(
          WidgetSpan(
            child: InkWell(
              onTap: () async {
                final Uri url = Uri.parse(matchedString);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                matchedString,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        );
      } else if (matchedString.startsWith('#')) {
        spans.add(
          WidgetSpan(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SearchPage(initialQuery: matchedString),
                  ),
                );
              },
              child: Text(
                matchedString,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(color: textColor),
      ));
    }

    return spans;
  }

  Widget _buildMediaWidget(
      BuildContext context, Map<String, dynamic> postData) {
    List<dynamic> rawUrls = postData['mediaUrls'] ?? [];
    List<String> mediaUrls = rawUrls.map((e) => e.toString()).toList();

    String? mediaUrl = postData['mediaUrl'] ?? postData['imageUrl'];
    if (mediaUrls.isEmpty && mediaUrl != null && mediaUrl.isNotEmpty) {
      mediaUrls.add(mediaUrl);
    }

    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    if (_isVideoUrl(mediaUrls[0]) && mediaUrls.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: PostVideoPlayer(
                  videoUrl: mediaUrls[0],
                  userName: postData['userName'] ?? widget.userName,
                  profileImageUrl: postData['userImage'] ??
                      postData['profileImageUrl'] ??
                      '',
                  uid: postData['uid'] ?? widget.userId,
                  postId: postData['postId'] ?? '',
                  role: postData['role'] ?? 'member',
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.download,
                        color: Colors.white, size: 20),
                    onPressed: () {
                      Map<String, dynamic> tempUserData = {
                        'profileImageUrl': postData['userImage'] ??
                            postData['profileImageUrl'] ??
                            ''
                      };
                      _showAdAndDownload(mediaUrls[0], tempUserData);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (mediaUrls.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: GestureDetector(
          onTap: () => NavigationHelper.push(
            context,
            FullScreenGalleryScreen(mediaUrls: mediaUrls, initialIndex: 0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 400,
                minHeight: 200,
              ),
              width: double.infinity,
              child: Image.network(
                mediaUrls[0],
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return Text(
                        isMm ? "ပုံဖွင့်၍မရပါ" : "Failed to load image",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: ClipRRect(
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
              onTap: () => NavigationHelper.push(
                context,
                FullScreenGalleryScreen(
                    mediaUrls: mediaUrls, initialIndex: index),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    mediaUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
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
      ),
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
    this.profileImageUrl,
    required this.uid,
    required this.postId,
    required this.role,
    required this.userName,
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
        final isMm = isMyanmarNotifier.value;
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
      final isMm = isMyanmarNotifier.value;
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
          _isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              : ValueListenableBuilder<bool>(
                  valueListenable: isMyanmarNotifier,
                  builder: (context, isMm, child) {
                    return IconButton(
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

// -------------------------------------------------------------
// Comment BottomSheet
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

      // 🌟 Transaction မစခင် Post Owner ရဲ့ Data ကို အရင် Read (ဖတ်) ပါ
      DocumentSnapshot? ownerDoc;
      if (currentUid != widget.postOwnerId) {
        ownerDoc = await ownerRef.get();
      }

      // 🌟 Transaction စတင်ခြင်း
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

        // ကိုယ့် Post ကိုကိုယ် Comment ပေးတာ မဟုတ်မှသာ ၃၀ ကျပ် ပေါင်းမည်
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

      if (currentUid != widget.postOwnerId) {
        String msg = "$userName is comment on your post: $commentText";
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

  Future<void> _deleteComment(String commentId, String commentAuthorUid) async {
    DocumentReference ownerRef =
        FirebaseFirestore.instance.collection('users').doc(widget.postOwnerId);

    DocumentSnapshot? ownerDoc;
    if (commentAuthorUid != widget.postOwnerId && commentAuthorUid.isNotEmpty) {
      ownerDoc = await ownerRef.get();
    }

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentReference commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);
      transaction.delete(commentRef);

      DocumentReference postRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      transaction.update(postRef, {
        'commentsCount': FieldValue.increment(-1),
      });

      if (commentAuthorUid != widget.postOwnerId &&
          ownerDoc != null &&
          ownerDoc.exists) {
        var ownerData = ownerDoc.data() as Map<String, dynamic>?;
        if (ownerData?['monetizationStatus'] == 'approved') {
          double currentBalance = (ownerData?['balance'] ?? 0).toDouble();
          double newBalance = currentBalance >= 30 ? currentBalance - 30 : 0;

          transaction.update(ownerRef, {
            'balance': newBalance,
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

        String mentionMsg =
            "$senderName is mentioning you in a comment: $commentText";

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
          NotificationService.sendNotification(
              userDoc['fcmToken'], mentionMsg, "New Mention!", 'message');
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
    Color menuBgColor = isDark
        ? const Color(0xFF1E1E1E).withOpacity(0.9)
        : Colors.white.withOpacity(0.95);
    Color itemTextColor = textColor;
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    // 🌟 ၁။ အပြင်ဘက်မှာ Padding ထည့်ပြီး viewInsets.bottom ကို ခံပေးပါ
    return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
          // 🌟 ၂။ Container ရဲ့ padding ထဲမှာတော့ viewInsets ကို ဖြုတ်ပြီး ပုံမှန် padding ပဲ ထားပါတော့
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16,
          ),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
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
                        child: ValueListenableBuilder<bool>(
                          valueListenable: isMyanmarNotifier,
                          builder: (context, isMm, child) {
                            return Text(
                              isMm ? "Comment မရှိသေးပါ။" : "No comments yet.",
                              style: TextStyle(color: textColor),
                            );
                          },
                        ),
                      );
                    }

                    // (ကျန်ရှိနေတဲ့ ListView/Comments များကို ဆက်ရေးပါ)
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;

                        String commentUid = data['uid'] ?? '';
                        String name = data['userName'] ?? "အသုံးပြုသူ";
                        String avatar = data['userImage'] ?? "";
                        String commentText = data['text'] ?? "";
                        bool isEdited = data['isEdited'] ?? false;

                        bool canModify = (commentUid == currentUid) ||
                            (widget.postOwnerId == currentUid);

                        return ListTile(
                          leading: GestureDetector(
                            onTap: () {
                              if (commentUid.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OtherProfilePage(
                                      userId: commentUid,
                                      userName: name,
                                    ),
                                  ),
                                );
                              }
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
                          title: GestureDetector(
                            onTap: () {
                              if (commentUid.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OtherProfilePage(
                                      userId: commentUid,
                                      userName: name,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(commentUid)
                                  .get(),
                              builder: (context, snapshot) {
                                String role = 'member';
                                if (snapshot.hasData && snapshot.data!.exists) {
                                  role = (snapshot.data!.data()
                                          as Map<String, dynamic>)['role'] ??
                                      'member';
                                }

                                return Row(
                                  children: [
                                    GoldenNameWidget(
                                      name: name,
                                      role: role,
                                      fontSize: 14,
                                    ),
                                    if (isEdited) ...[
                                      const SizedBox(width: 6),
                                      ValueListenableBuilder<bool>(
                                        valueListenable: isMyanmarNotifier,
                                        builder: (context, isMm, child) {
                                          return Text(
                                            isMm ? "(ပြင်ဆင်ပြီး)" : "(Edited)",
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                          subtitle: Text(commentText,
                              style: TextStyle(color: textColor)),
                          trailing: canModify
                              ? PopupMenuButton<String>(
                                  color: menuBgColor,
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
                                      _deleteComment(doc.id, commentUid);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    if (commentUid == currentUid)
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit,
                                                size: 16, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            ValueListenableBuilder<bool>(
                                              valueListenable:
                                                  isMyanmarNotifier,
                                              builder: (context, isMm, child) {
                                                return Text(
                                                  isMm ? "ပြင်ရန်" : "Edit",
                                                  style: TextStyle(
                                                      color: itemTextColor),
                                                );
                                              },
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
                                          ValueListenableBuilder<bool>(
                                            valueListenable: isMyanmarNotifier,
                                            builder: (context, isMm, child) {
                                              return Text(
                                                isMm ? "ဖျက်ရန်" : "Delete",
                                                style: TextStyle(
                                                    color: itemTextColor),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
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
                        ),
                        onTap: () => onUserSelected(userData),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Text(
                            isMm
                                ? "Comment ကို ပြင်ဆင်နေသည်..."
                                : "Editing comment...",
                            style: const TextStyle(
                                color: Colors.blue, fontSize: 12),
                          );
                        },
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _editingCommentId = null;
                            _commentController.clear();
                          });
                        },
                        child: ValueListenableBuilder<bool>(
                          valueListenable: isMyanmarNotifier,
                          builder: (context, isMm, child) {
                            return Text(
                              isMm ? "မလုပ်တော့ပါ" : "Cancel",
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              SafeArea(
                bottom: true,
                child: ValueListenableBuilder<bool>(
                  valueListenable: isMyanmarNotifier,
                  builder: (context, isMm, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: _isEditing
                                  ? (isMm
                                      ? "Comment ကို ပြင်ရန်..."
                                      : "Edit Comment...")
                                  : (isMm
                                      ? "Comment ရေးရန် (@ဖြင့် Mention ခေါ်နိုင်သည်)..."
                                      : "Write a comment (@ to mention)..."),
                              hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.grey[400] : Colors.grey),
                              border: const OutlineInputBorder(),
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
                    );
                  },
                ),
              )
            ],
          ),
        ));
  }
}

// -------------------------------------------------------------
// PostVideoPlayer
// -------------------------------------------------------------
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

  @override
  void initState() {
    super.initState();

    // URL နောက်က #t=0.1 ကို ဖြုတ်ပြီး တိုက်ရိုက်သုံးပါ (Query Parameters တွေ မပျက်စေရန်)
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
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color backgroundColor;

  _SliverAppBarDelegate(this._tabBar, this.backgroundColor);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
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
  // ignore: unused_field
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
