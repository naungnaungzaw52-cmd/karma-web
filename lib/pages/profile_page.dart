// ignore_for_file: use_build_context_synchronously, avoid_print

// ignore: unused_import
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:karma/pages/home_page.dart';
import 'package:karma/pages/other_profile_page.dart';
import 'package:karma/pages/search_page.dart';
import 'package:karma/pages/user_list_page.dart';
import 'package:karma/services/r2_service.dart';
import 'package:karma/services/notification_service.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:karma/utilis/navigation_helper.dart';
import 'package:karma/widgets/full_screen_gallery.dart';
import 'package:karma/main.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/pages/setting_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // <--- ဒီနေရာမှာ ဒါပါဖို့လိုပါတယ်
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _hobbiesController = TextEditingController();
  bool _isUploading = false;

  late TabController _tabController; // <--- TabController ကြေညာချက်

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2,
        vsync: this); // <--- အရှည် 2 ခု (Posts နဲ့ Videos) ထည့်ထားပါတယ်
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hobbiesController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ကျန်တဲ့ Helper Methods တွေ (ဥပမာ - _isVideoUrl, _toggleLike စသည်တို့ ဆက်ရှိနေပါစေ)
  // 🌟 လိုအပ်သော Theme variables နှင့် Getter များ ဖြည့်စွက်ခြင်း
  bool get _isDarkTheme =>
      Provider.of<ThemeProvider>(context).currentTheme != 'Default';

  Color get _cardBgColor {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (themeProvider.currentTheme == 'Default') {
      return Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      return Colors.white
          .withOpacity(0.15); // Glassmorphism ပုံစံ (အရောင်ဖျော့)
    } else {
      return Colors.black.withOpacity(0.3); // Dark/Gradient Theme များအတွက်
    }
  }

  Color get _postTextColor =>
      Provider.of<ThemeProvider>(context).getTextColor();
  final List<String> avatars = [
    "https://cdn-icons-png.flaticon.com/512/3774/3774299.png",
    "https://cdn-icons-png.flaticon.com/512/3774/3774291.png",
    "https://cdn-icons-png.flaticon.com/512/3135/3135768.png",
    "https://cdn-icons-png.flaticon.com/512/3135/3135810.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140048.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140037.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140047.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140051.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140061.png",
    "https://cdn-icons-png.flaticon.com/512/1995/1995575.png",
  ];

  // --- Like & Notification Logic ---
  Future<void> _toggleLike(String postId, List likes, String ownerId) async {
    String uid = user!.uid;
    var postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    String userName = user?.displayName ?? "Unknown User";

    DocumentSnapshot senderDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    String senderAvatar = '';
    if (senderDoc.exists) {
      var data = senderDoc.data() as Map<String, dynamic>?;
      senderAvatar = data?['profileImageUrl'] ??
          data?['profileImage'] ??
          data?['photoURL'] ??
          user?.photoURL ??
          '';
    }

    if (likes.contains(uid)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([uid])
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([uid])
      });
      if (uid != ownerId) {
        String msg = "$userName is liked your post.";

        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': ownerId,
          'senderId': uid,
          'senderAvatar': senderAvatar,
          'postId': postId,
          'message': msg,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        DocumentSnapshot ownerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(ownerId)
            .get();
        if (ownerDoc.exists && ownerDoc['fcmToken'] != null) {
          NotificationService.sendNotification(
              ownerDoc['fcmToken'], msg, "New Like!", 'message');
        }
      }
    }
  }

  Widget _buildUserVideosGrid(bool isMm, ThemeProvider themeProvider) {
    Color textColor = _postTextColor;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: user!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ဗီဒီယိုပါသော Post များကိုသာ စစ်ထုတ်ခြင်း
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
            child: Text(
              isMm ? "ဗီဒီယိုများ မရှိသေးပါ။" : "No videos post yet.",
              style: TextStyle(color: textColor),
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
            var post = videoDocs[index];
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
                // 🌟 OtherProfilePage မှာလို နှိပ်လိုက်ရင် Video Full Screen ထွက်လာစေရန်
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
                            userName: data['userName'] ??
                                user?.displayName ??
                                "Unknown User",
                            profileImageUrl: data['userImage'] ??
                                data['profileImageUrl'] ??
                                user?.photoURL ??
                                '',
                            uid: data['uid'] ?? user!.uid,
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
                    // 🌟 ဗီဒီယို အစ (First Frame / Thumbnail) ပေါ်စေရန် PostVideoPlayer ကို သုံးပေးခြင်း
                    if (videoUrl.isNotEmpty)
                      PostVideoPlayer(
                        videoUrl: videoUrl,
                        userName: data['userName'] ??
                            user?.displayName ??
                            "Unknown User",
                        profileImageUrl: data['userImage'] ??
                            data['profileImageUrl'] ??
                            user?.photoURL ??
                            '',
                        uid: data['uid'] ?? user!.uid,
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndUploadProfileImage(
      ImageSource source, Map currentData) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // 🌟 Flutter Web ရော Mobile ပါ stream/namespace error လုံးဝမတက်အောင် XFile နဲ့ Bytes ကို တိုက်ရိုက်သုံးခြင်း
      Uint8List fileBytes = await pickedFile.readAsBytes();
      String fileName = "profile_${DateTime.now().millisecondsSinceEpoch}.jpg";

      XFile xFile = XFile.fromData(fileBytes, name: fileName);
      String? newImageUrl = await R2Service.uploadFile(xFile, 'profile_images');

      if (newImageUrl != null) {
        String? oldImageUrl = currentData['profileImageUrl'];
        if (oldImageUrl != null &&
            oldImageUrl
                .contains("pub-4e491f3d159e4aa4bc2678deef207097.r2.dev")) {
          await R2Service.deleteFile(oldImageUrl);
        }
        await _updateProfileAndPosts(
            _nameController.text, _bioController.text, newImageUrl);
        if (!mounted) return;
        NavigationHelper.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isMyanmarNotifier.value
                  ? 'Profile ပုံ အောင်မြင်စွာ တင်ပြီးပါပြီ'
                  : 'Profile image uploaded successfully')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isMyanmarNotifier.value
                  ? 'ပုံတင်ခြင်း မအောင်မြင်ပါ။'
                  : 'Upload failed')),
        );
      }
    } catch (e) {
      print("Profile Image Upload Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload Exception: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  /// 🌟 ပရိုဖိုင် အချက်အလက် (နာမည်၊ ပုံ၊ Bio)၊ ပို့စ်ဟောင်းများ၊ ကွန်မန့်များနှင့် နာမည်ပြောင်းသမျှ Notification များကိုပါ တစ်ခါတည်း အပ်ဒိတ်လုပ်ရန်
  Future<void> _updateProfileAndPosts(String name, String bio, String avatarUrl,
      {List<String>? hobbies}) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final updatedHobbies = hobbies ?? const <String>[];

      // ၁။ Users Collection ထဲမှာ Profile ကို အရင် Update လုပ်မယ်
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'displayName': name,
        'userName': name,
        'bio': bio,
        'hobbies': updatedHobbies,
        'profileImageUrl': avatarUrl,
      }, SetOptions(merge: true));

      // Firebase Auth ရဲ့ DisplayName ကိုလည်း ပါ တစ်ခါတည်း Update လုပ်မယ်
      await currentUser.updateDisplayName(name);

      // ၂. Posts Collection ထဲက ဒီ User ရဲ့ uid နဲ့ တူတဲ့ Post တွေအားလုံးကို ရှာမယ်
      QuerySnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: currentUser.uid)
          .get();

      // ၃. Comment တွေပါ လိုက်ပြင်နိုင်ရန် Collection Group ကိုသုံးပြီး ဒီ User ရဲ့ Comment အားလုံးကို ရှာမယ်
      QuerySnapshot commentSnapshot = await FirebaseFirestore.instance
          .collectionGroup('comments')
          .where('uid', isEqualTo: currentUser.uid)
          .get();

      // ၄. 🌟 Notification တွေထဲမှာ ကိုယ်ပို့ထားခဲ့တဲ့ senderAvatar တွေကိုပါ လိုက်ပြင်ရန်
      QuerySnapshot notiSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('senderId', isEqualTo: currentUser.uid)
          .get();

      // ၅. Batch Write ကိုသုံးပြီး Post တွေ၊ Comment တွေနဲ့ Notification တွေထဲက နာမည်နဲ့ ပုံကို တစ်ခါတည်း အကုန်လိုက်ပြင်မယ်
      WriteBatch batch = FirebaseFirestore.instance.batch();
      int operationCount = 0;

      for (var doc in postSnapshot.docs) {
        batch.update(doc.reference, {
          'userName': name,
          'displayName': name,
          'userImage': avatarUrl,
        });
        operationCount++;
        if (operationCount >= 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }

      for (var doc in commentSnapshot.docs) {
        batch.update(doc.reference, {
          'userName': name,
          'userImage': avatarUrl,
        });
        operationCount++;
        if (operationCount >= 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }

      for (var doc in notiSnapshot.docs) {
        batch.update(doc.reference, {
          'senderAvatar': avatarUrl,
        });
        operationCount++;
        if (operationCount >= 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }

      // Batch ကို Execute လုပ်ပါ (Firestore ၏ 500 limit ကို ကာကွယ်ရန် ဖြတ်တောက်ပေးထားသည်)
      if (operationCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      print('Error updating profile, posts, comments and notifications: $e');
    }
  }

  Future<void> _deletePost(String postId, List<dynamic>? mediaUrls) async {
    if (mediaUrls != null) {
      for (var url in mediaUrls) {
        if (url != null && url.toString().isNotEmpty) {
          await R2Service.deleteFile(url.toString());
        }
      }
    }
    await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
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

  bool _isVideoUrl(String url) {
    final lowercase = url.toLowerCase();
    return lowercase.contains('.mp4') ||
        lowercase.contains('.mov') ||
        lowercase.contains('.avi') ||
        lowercase.contains('.m4v') ||
        lowercase.contains('.webm') ||
        lowercase.contains('.mpeg') ||
        lowercase.contains('.wmv') ||
        lowercase.contains('.flv') ||
        lowercase.contains('video/');
  }

  /// 🌟 Theme ရွေးချယ်သည့် Dialog (Glassmorphism Blur ပုံစံဖြင့်)
  void _showThemeSelectionDialog(
      BuildContext context, bool isMm, String? role) {
    final String normalizedRole = (role ?? '').trim().toLowerCase();
    bool isSpecialUser = (normalizedRole == 'admin' ||
        normalizedRole == 'vip' ||
        normalizedRole == 'gold_user' ||
        normalizedRole == 'team_karma');

    // 🌟 Notification/Tip ပုံစံအတိုင်း Theme ကိုလိုက်ပြီး Dialog background အရောင် သတ်မှတ်ခြင်း
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    Color dialogBgColor;
    if (themeProvider.currentTheme == 'Default') {
      dialogBgColor = Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      dialogBgColor = const Color(0xFF1E1E1E).withOpacity(0.85);
    } else {
      dialogBgColor = const Color(0xFF121212).withOpacity(0.85);
    }

    Color textColor = themeProvider.getTextColor();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              dialogBgColor, // 🌟 Theme အလိုက် မှိန်မှိန် နောက်ခံအရောင်
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            isMm ? "Theme တစ်ခု ရွေးချယ်ပါ" : "Select a Theme",
            style: TextStyle(color: textColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.grey),
                  title:
                      Text("Default Theme", style: TextStyle(color: textColor)),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme('Default');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode, color: Colors.black87),
                  title: Text("Dark Theme", style: TextStyle(color: textColor)),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme('Dark Theme');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.flash_on,
                      color: Color.fromARGB(255, 102, 10, 208)),
                  title:
                      Text("Neon Purple", style: TextStyle(color: textColor)),
                  onTap: () {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .setTheme('Neon Purple');
                    Navigator.pop(context);
                  },
                ),
                if (isSpecialUser) ...[
                  ListTile(
                    leading: const Icon(Icons.wb_sunny, color: Colors.orange),
                    title:
                        Text("Sunset Glow", style: TextStyle(color: textColor)),
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .setTheme('Sunset Glow');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_circle, color: Colors.blue),
                    title:
                        Text("Royal Sky", style: TextStyle(color: textColor)),
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .setTheme('Royal Sky');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.grass, color: Colors.green),
                    title: Text("Forest Green",
                        style: TextStyle(color: textColor)),
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .setTheme('Forest Green');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.local_florist, color: Colors.pink),
                    title:
                        Text("Soft Rose", style: TextStyle(color: textColor)),
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .setTheme('Soft Rose');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title:
                        Text("Luxury Gold", style: TextStyle(color: textColor)),
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .setTheme('Luxury Gold');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.water, color: Colors.blue),
                    title: Text("Ocean Gradient",
                        style: TextStyle(color: textColor)),
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .setTheme('Ocean Gradient');
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.nights_stay, color: Colors.deepPurple),
                    title: Text("Midnight Velvet",
                        style: TextStyle(color: textColor)),
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .setTheme('Midnight Velvet');
                      Navigator.pop(context);
                    },
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      isMm
                          ? "အဆင့်မြင့် Theme များအတွက် Golden Mark လိုအပ်ပါသည်။"
                          : "Upgrade to Golden User for more themes.",
                      style: const TextStyle(fontSize: 12, color: Colors.amber),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
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
        // ignore: unnecessary_cast
        final senderData = senderSnapshot.data() as Map<String, dynamic>?;
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

  // 🌟 အသစ်ထည့်သွင်းပေးလိုက်သော _buildStatItem Method
  // ignore: unused_element
  Widget _buildStatItem(
      String count, String label, bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

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
              title: Text(
                isMm ? "ကျွန်ုပ်၏ Profile" : "My Profile",
                style: TextStyle(
                  color: themeProvider.getTextColor(),
                ),
              ),
              centerTitle: true,
              iconTheme: IconThemeData(
                color: themeProvider.getTextColor(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    NavigationHelper.push(
                      context,
                      SettingsPage(
                        isMm: isMm,
                        isMyanmarNotifier: isMyanmarNotifier,
                        showThemeSelectionDialog: _showThemeSelectionDialog,
                      ),
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user!.uid)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      var data =
                          userSnapshot.data!.data() as Map<String, dynamic>? ??
                              {};
                      String role = data['role'] ?? 'member';
                      List<dynamic> hobbies = data['hobbies'] ?? [];

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final themeProvider =
                            Provider.of<ThemeProvider>(context, listen: false);
                        if (role != 'gold_user' &&
                            role != 'admin' &&
                            role != 'vip') {
                          if (themeProvider.currentTheme != 'Default' &&
                              themeProvider.currentTheme != 'Dark Theme' &&
                              themeProvider.currentTheme != 'Neon Purple') {
                            themeProvider.setTheme('Default');
                          }
                        }
                      });
                      String avatar = data['profileImageUrl'] ?? avatars[0];

                      int followerCount = data['followersCount'] ?? 0;
                      int followingCount = data['followingCount'] ?? 0;

                      return CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.all(8.0),
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: _cardBgColor,
                                borderRadius: BorderRadius.circular(10.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(_isDarkTheme ? 0.2 : 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // အပေါ်ပိုင်း - ပရိုဖိုင်ပုံ၊ နာမည်၊ Username (ဘေးချင်းယှဉ်ရန်)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // ဘယ်ဘက်ခြမ်း - Profile Picture
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                  _isDarkTheme ? 0.3 : 0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 40,
                                          backgroundImage: NetworkImage(avatar),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // အလယ်/ညာဘက်ခြမ်း - အမည်နှင့် Username
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            GoldenNameWidget(
                                              name: data['displayName'] ??
                                                  user?.displayName ??
                                                  (isMm
                                                      ? "Unknown User"
                                                      : "User"),
                                              role: data['role'],
                                              fontSize: 20,
                                              isWhiteBackground: !_isDarkTheme,
                                            ),
                                            if (data['username'] != null &&
                                                data['username']
                                                    .toString()
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '@${data['username']}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: _isDarkTheme
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Following နှင့် Followers များကို အောက်ဘက်တွင် ဘယ်ညာ မျှတစွာ ပြသရန်
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      GestureDetector(
                                        onTap: () => NavigationHelper.push(
                                          context,
                                          UserListPage(
                                            title: "Following",
                                            userId: user!.uid,
                                            isFollowers: false,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '$followingCount ',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: _postTextColor,
                                              ),
                                            ),
                                            Text(
                                              'Following',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _isDarkTheme
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height: 16,
                                        width: 1,
                                        color: _isDarkTheme
                                            ? Colors.white24
                                            : Colors.grey[300],
                                      ),
                                      GestureDetector(
                                        onTap: () => NavigationHelper.push(
                                          context,
                                          UserListPage(
                                            title: "Followers",
                                            userId: user!.uid,
                                            isFollowers: true,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '$followerCount ',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: _postTextColor,
                                              ),
                                            ),
                                            Text(
                                              'Followers',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _isDarkTheme
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Hobbies များကို Tag/Chip ပုံစံဖြင့် ပြသရန်
                                  if (hobbies.isNotEmpty) ...[
                                    Wrap(
                                      spacing: 6.0,
                                      runSpacing: 6.0,
                                      children: hobbies.map((hobby) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _isDarkTheme
                                                ? Colors.blue.withOpacity(0.2)
                                                : Colors.blue.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color:
                                                  Colors.blue.withOpacity(0.4),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            hobby.toString(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _isDarkTheme
                                                  ? Colors.blueAccent[100]
                                                  : Colors.blue[800],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 14),
                                  ],

                                  // ပရိုဖိုင်ပြင်ဆင်ရန် ခလုတ် (Edit Profile Button)
                                  GestureDetector(
                                    onTap: () => _showEditModal(data, isMm),
                                    child: Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
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
                                      child: Text(
                                        isMm
                                            ? "ပရိုဖိုင်ပြင်ဆင်ရန်"
                                            : "Edit Profile",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _isDarkTheme
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Bio ကို အလယ်တည့်တည့်တွင်ထားရှိခြင်း
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
                                        // 👈 အပြင်ဘက်က ရလာတဲ့ isMm ကို တိုက်ရိုက်သုံးပါ
                                        String bioText = (data['bio'] != null &&
                                                data['bio']
                                                    .toString()
                                                    .isNotEmpty)
                                            ? data['bio']
                                            : "No bio yet";

                                        final urlRegExp =
                                            RegExp(r'(https?:\/\/[^\s]+)');
                                        final match =
                                            urlRegExp.firstMatch(bioText);

                                        if (match != null) {
                                          String urlStr = match.group(0)!;
                                          int startIndex =
                                              bioText.indexOf(urlStr);
                                          String beforeText =
                                              bioText.substring(0, startIndex);
                                          String afterText = bioText.substring(
                                              startIndex + urlStr.length);

                                          return RichText(
                                            textAlign: TextAlign.center,
                                            text: TextSpan(
                                              style: TextStyle(
                                                color: _postTextColor,
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
                                                      if (await canLaunchUrl(
                                                          url)) {
                                                        await launchUrl(url,
                                                            mode: LaunchMode
                                                                .externalApplication);
                                                      }
                                                    },
                                                    child: Text(
                                                      urlStr,
                                                      style: const TextStyle(
                                                        color: Colors.blue,
                                                        decoration:
                                                            TextDecoration
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
                                              color: _postTextColor,
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

                          // 🌟 1. Posts နဲ့ Videos အတွက် TabBar ကို Sticky ပုံစံဖြင့် ထည့်သွင်းခြင်း
                          ValueListenableBuilder<bool>(
                            valueListenable: isMyanmarNotifier,
                            builder: (context, isMmValue, child) {
                              return SliverPersistentHeader(
                                pinned: true,
                                delegate: _SliverAppBarDelegate(
                                  TabBar(
                                    controller: _tabController,
                                    labelColor: Colors.blueAccent,
                                    unselectedLabelColor: _isDarkTheme
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    indicatorColor: Colors.blueAccent,
                                    tabs: const [
                                      Tab(
                                        icon: Icon(Icons.grid_on),
                                        text:
                                            "Posts", // 👈 အင်္ဂလိပ်လို ပုံသေပြောင်းပါ
                                      ),
                                      Tab(
                                        icon: Icon(Icons.video_library),
                                        text:
                                            "Videos", // 👈 အင်္ဂလိပ်လို ပုံသေပြောင်းပါ
                                      ),
                                    ],
                                  ),
                                  _cardBgColor,
                                  backgroundColor:
                                      themeProvider.currentTheme == 'Default'
                                          ? Colors.white.withOpacity(0.4)
                                          : const Color(0xFF1E1E1E)
                                              .withOpacity(0.35),
                                ),
                              );
                            },
                          ),
                          // 🌟 2. Tab လိုက်အချက်အလက်ပြရန် TabBarView ကို SliverFillRemaining ဖြင့် ချိတ်ဆက်ခြင်း
                          SliverFillRemaining(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildUserPostsList(isMm, themeProvider,
                                    isVideoTab: false), // Posts Tab
                                _buildUserVideosGrid(isMm,
                                    themeProvider), // Videos Tab (ဗီဒီယိုဇယားကွက်ပြမည့် Function)
                              ],
                            ),
                          ),
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

  Widget _buildUserPostsList(bool isMm, ThemeProvider themeProvider,
      {bool isVideoTab = false}) {
    bool isDarkTheme = themeProvider.currentTheme != 'Default';
    Color cardBgColor = _cardBgColor;
    Color postTextColor = themeProvider.getTextColor();
    Color subTextColor = isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('uid', isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text("Error: ${snapshot.error}",
                  style: TextStyle(color: postTextColor)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data!.docs;

        // Tab အလိုက် Filter လုပ်ခြင်း (Posts vs Videos)
        docs = docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          List<dynamic> rawUrls = data['mediaUrls'] ?? [];
          List<String> mediaUrls = rawUrls.map((e) => e.toString()).toList();
          String? singleMediaUrl = data['mediaUrl'] ?? data['imageUrl'];
          if (mediaUrls.isEmpty &&
              singleMediaUrl != null &&
              singleMediaUrl.isNotEmpty) {
            mediaUrls.add(singleMediaUrl);
          }

          bool isVideoPost = mediaUrls.isNotEmpty &&
              (mediaUrls[0].toLowerCase().contains('.mp4') ||
                  mediaUrls[0].toLowerCase().contains('.mov') ||
                  mediaUrls[0].toLowerCase().contains('.webm') ||
                  mediaUrls[0].toLowerCase().contains('.mkv'));

          if (isVideoTab) {
            return isVideoPost; // Videos tab အတွက် ဗီဒီယိုပါမှပြမယ်
          } else {
            return true; // Posts tab အတွက် အားလုံးပြမယ်
          }
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                isVideoTab
                    ? (isMm
                        ? "ဗီဒီယို ပို့စ်များ မရှိသေးပါ။"
                        : "No video posts yet.")
                    : (isMm ? "ပို့စ်များ မရှိသေးပါ။" : "No posts yet."),
                style: TextStyle(color: subTextColor),
              ),
            ),
          );
        }

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
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var post = docs[index];
            var data = post.data() as Map<String, dynamic>;
            bool isPinned = data['isPinned'] ?? false;
            Timestamp? t = data['createdAt'] as Timestamp?;
            String time = t != null
                ? "${t.toDate().year}-${t.toDate().month.toString().padLeft(2, '0')}-${t.toDate().day.toString().padLeft(2, '0')} ${t.toDate().hour.toString().padLeft(2, '0')}:${t.toDate().minute.toString().padLeft(2, '0')}"
                : "";

            List likes = data['likes'] ?? [];

            List<dynamic> rawUrls = data['mediaUrls'] ?? [];
            List<String> mediaUrls = rawUrls.map((e) => e.toString()).toList();

            String? singleMediaUrl = data['mediaUrl'] ?? data['imageUrl'];
            if (mediaUrls.isEmpty &&
                singleMediaUrl != null &&
                singleMediaUrl.isNotEmpty) {
              mediaUrls.add(singleMediaUrl);
            }

            bool isVideoPost = mediaUrls.isNotEmpty &&
                (mediaUrls[0].toLowerCase().contains('.mp4') ||
                    mediaUrls[0].toLowerCase().contains('.mov') ||
                    mediaUrls[0].toLowerCase().contains('.webm') ||
                    mediaUrls[0].toLowerCase().contains('.mkv'));

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: cardBgColor,
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPinned)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.push_pin,
                                size: 14, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              isMm ? "အထူးပြု ပို့စ် (Pinned)" : "Pinned Post",
                              style: const TextStyle(
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
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: (data['userImage'] != null &&
                                  data['userImage'].toString().isNotEmpty)
                              ? NetworkImage(data['userImage'])
                              : (user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null) as ImageProvider?,
                          child: (data['userImage'] == null &&
                                  user?.photoURL == null)
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        title: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(data['uid'])
                              .get(),
                          builder: (context, snapshot) {
                            String role = 'member';
                            if (snapshot.hasData && snapshot.data!.exists) {
                              var userData =
                                  snapshot.data!.data() as Map<String, dynamic>;
                              role = userData['role'] ?? 'member';
                            }

                            return GoldenNameWidget(
                              name: data['displayName'] ??
                                  user?.displayName ??
                                  (isMm ? "အသုံးပြုသူ" : "User"),
                              role: role,
                              fontSize: 16,
                              isWhiteBackground: !isDarkTheme,
                            );
                          },
                        ),
                        subtitle: Text(
                          time,
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                        trailing: PopupMenuButton<String>(
                          color: themeProvider.currentTheme == 'Default'
                              ? Colors.white.withOpacity(0.9)
                              : const Color(0xFF1E1E1E).withOpacity(0.9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: themeProvider.currentTheme == 'Default'
                                  ? Colors.grey.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.15),
                              width: 1.0,
                            ),
                          ),
                          icon: Icon(Icons.more_vert,
                              size: 20, color: postTextColor),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              NavigationHelper.push(
                                context,
                                EditPostPage(
                                  postId: post.id,
                                  currentText: data['text'] ?? '',
                                  currentMediaUrl: mediaUrls.isNotEmpty
                                      ? mediaUrls[0]
                                      : null,
                                ),
                              );
                            } else if (value == 'delete') {
                              _deletePost(post.id, mediaUrls);
                            } else if (value == 'pin') {
                              await FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(post.id)
                                  .update({'isPinned': !isPinned});
                            }
                          },
                          itemBuilder: (context) {
                            final bool isLight =
                                themeProvider.currentTheme == 'Default';
                            final Color itemTextColor =
                                isLight ? Colors.black87 : Colors.white70;

                            return [
                              PopupMenuItem(
                                value: 'pin',
                                child: Row(
                                  children: [
                                    const Icon(Icons.push_pin,
                                        size: 18, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(
                                      isPinned
                                          ? (isMm ? "Pin ဖြုတ်ရန်" : "Unpin")
                                          : (isMm ? "Pin တင်ရန်" : "Pin Post"),
                                      style: TextStyle(color: itemTextColor),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit,
                                        size: 18, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Text(
                                      isMm ? "ပြင်ရန်" : "Edit",
                                      style: TextStyle(color: itemTextColor),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete,
                                        size: 18, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text(
                                      isMm ? "ဖျက်ရန်" : "Delete",
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ];
                          },
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
                                style: TextStyle(
                                    fontSize: 15, color: postTextColor),
                                children: _buildHashtagTextSpans(
                                    text, context, postTextColor),
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
                    _buildMediaWidget(context, data, mediaUrls, isMm),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            likes.contains(user!.uid)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.red,
                            size: 22,
                          ),
                          onPressed: () =>
                              _toggleLike(post.id, likes, data['uid']),
                        ),
                        Text("${likes.length}",
                            style:
                                TextStyle(fontSize: 13, color: subTextColor)),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(
                            Icons.comment_outlined,
                            size: 22,
                            color: postTextColor,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              barrierColor: Colors.transparent,
                              builder: (context) => BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: _CommentBottomSheet(
                                  postId: post.id,
                                  postOwnerId: data['uid'],
                                  isDarkTheme: isDarkTheme,
                                ),
                              ),
                            );
                          },
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .doc(post.id)
                              .collection('comments')
                              .snapshots(),
                          builder: (context, snapshot) {
                            int count = snapshot.hasData
                                ? snapshot.data!.docs.length
                                : 0;
                            return Text("$count",
                                style: TextStyle(
                                    fontSize: 13, color: subTextColor));
                          },
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
                                  color: subTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isVideoPost) ...[
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.remove_red_eye_outlined,
                                size: 18,
                                color: isDarkTheme
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${data['viewCount'] ?? 0}",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkTheme
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

  // 🌟 Hashtag နှင့် Link များကို အပြာရောင်ပြောင်းပေးပြီး နှိပ်၍ရစေသော Method
  List<InlineSpan> _buildHashtagTextSpans(
      String text, BuildContext context, Color textColor) {
    final List<InlineSpan> spans = [];

    // URL နှင့် #Hashtag များကို ရှာရန် Regular Expression
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
        // Link ဖြစ်နေလျှင်
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
        // 🌟 Hashtag ဖြစ်နေလျှင် အပြာရောင်ပြမည်၊ နှိပ်ပါက search_page.dart သို့ သွားမည်
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

  Widget _buildMediaWidget(BuildContext context, Map<String, dynamic> postData,
      List<String> mediaUrls, bool isMm) {
    List<dynamic> rawUrls = postData['mediaUrls'] ?? [];
    List<String> mediaUrls = rawUrls.map((e) => e.toString()).toList();

    String? mediaUrl = postData['mediaUrl'] ?? postData['imageUrl'];
    if (mediaUrls.isEmpty && mediaUrl != null && mediaUrl.isNotEmpty) {
      mediaUrls.add(mediaUrl);
    }

    if (mediaUrls.isEmpty) return const SizedBox.shrink();

    // 🌟 1. ဗီဒီယို တစ်ခုတည်းရှိလျှင် (AspectRatio ဖြင့် ညီညာစွာပြသရန်)
    if (!_isImageUrl(mediaUrls[0]) && mediaUrls.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PostVideoPlayer(
              videoUrl: mediaUrls[0],
              userName: null,
              profileImageUrl: null,
              uid: null,
              postId: '',
              role: null,
            ),
          ),
        ),
      );
    }

    // 🌟 2. ပုံ တစ်ပုံတည်းရှိလျှင် (Fixed Height ဖြုတ်ပြီး မူရင်းပုံအချိုးအစားအတိုင်း အပြည့်ပြရန်)
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
                maxHeight:
                    400, // ပုံအရမ်းရှည်သွားပါက အများဆုံးအမြင့်သတ်မှတ်ချက်
                minHeight: 200,
              ),
              width: double.infinity,
              child: Image.network(
                mediaUrls[0],
                width: double.infinity,
                fit: BoxFit
                    .cover, // သို့မဟုတ် မူရင်းပုံအပြည့်ပြလိုပါက BoxFit.contain ကိုသုံးနိုင်သည်
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Text("ပုံဖွင့်၍မရပါ")),
              ),
            ),
          ),
        ),
      );
    }

    // 🌟 3. ပုံများစွာပါပါက Grid ပုံစံဖြင့်ပြသရန်
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

  void _showEditModal(Map data, bool isMm) {
    _nameController.text = data['displayName'] ?? user?.displayName ?? "";
    _bioController.text = data['bio'] ?? "";
    List<dynamic> existingHobbies = data['hobbies'] ?? [];
    _hobbiesController.text = existingHobbies.join(', ');
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
              builder: (context, setModalState) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: SizedBox(
                  height: 550,
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        Text(
                            isMm
                                ? "ကိုယ်ပိုင်ပုံ (သို့) Avatar ရွေးချယ်ပါ"
                                : "Choose Custom Photo or Avatar",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isUploading
                                  ? null
                                  : () async {
                                      await _pickAndUploadProfileImage(
                                          ImageSource.gallery, data);
                                      setModalState(() {});
                                    },
                              icon: const Icon(Icons.photo_library),
                              label: Text(
                                  isMm ? "ဂယ်လီယာမှ ပုံတင်မည်" : "Gallery"),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: _isUploading
                                  ? null
                                  : () async {
                                      await _pickAndUploadProfileImage(
                                          ImageSource.camera, data);
                                      setModalState(() {});
                                    },
                              icon: const Icon(Icons.camera_alt),
                              label: Text(isMm ? "ကင်မရာ" : "Camera"),
                            ),
                          ],
                        ),
                        if (_isUploading) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(),
                        ],
                        const Divider(height: 30),
                        Text(
                            isMm
                                ? "သို့မဟုတ် အောက်ပါ Avatar များမှ ရွေးပါ"
                                : "Or choose from avatars below",
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 10),
                        Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: avatars
                                .map((url) => GestureDetector(
                                    onTap: () async {
                                      await _updateProfileAndPosts(
                                          _nameController.text,
                                          _bioController.text,
                                          url);
                                      if (!mounted) return;
                                      NavigationHelper.pop(context);
                                    },
                                    child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.grey.shade200,
                                        backgroundImage: NetworkImage(url))))
                                .toList()),
                        const SizedBox(height: 20),
                        TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                                labelText: isMm ? "အမည်" : "Name")),
                        TextField(
                            controller: _bioController,
                            decoration:
                                const InputDecoration(labelText: "Bio")),
                        // 🌟 Hobbies ထည့်ရန် TextField အသစ်
                        TextField(
                            controller: _hobbiesController,
                            decoration: InputDecoration(
                                labelText: isMm
                                    ? "ဝါသနာများ (ကော်မာ ခြားရန် - ဥပမာ: Coding, Gaming)"
                                    : "Hobbies (Comma separated)")),
                        const SizedBox(height: 15),
                        ElevatedButton(
                          onPressed: () async {
                            // 🌟 ရိုက်ထည့်လိုက်သော Hobbies စာသားများကို List[String] သို့ ပြောင်းရန်
                            List<String> hobbiesList = _hobbiesController.text
                                .split(',')
                                .map((e) => e.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();

                            // 🌟 hobbies ကိုပါ ထည့်ပြီး update လုပ်ရန်
                            await _updateProfileAndPosts(
                              _nameController.text,
                              _bioController.text,
                              data['profileImageUrl'] ?? avatars[0],
                              hobbies:
                                  hobbiesList, // ဒီနေရာမှာ hobbies ထည့်ပေးဖို့လိုပါတယ်
                            );
                            if (!mounted) return;
                            NavigationHelper.pop(context);
                          },
                          child: Text(isMm ? "သိမ်းဆည်းမည်" : "Save"),
                        ),
                      ])),
                ),
              ),
            ));
  }
}

// --- Comment BottomSheet ---
class _CommentBottomSheet extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final bool isDarkTheme;

  const _CommentBottomSheet({
    required this.postId,
    required this.postOwnerId,
    required this.isDarkTheme,
  });

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

  void _onUserSelected(Map<String, dynamic> userData) {
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

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'uid': currentUid,
        'text': commentText,
        'userName': userName,
        'userImage': senderAvatar,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (currentUid != widget.postOwnerId) {
        String msg = "$userName commented on your post: $commentText";
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': widget.postOwnerId,
          'senderId': currentUid,
          'senderAvatar': senderAvatar,
          'postId': widget.postId,
          'message': msg,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        DocumentSnapshot ownerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.postOwnerId)
            .get();
        if (ownerDoc.exists && ownerDoc['fcmToken'] != null) {
          NotificationService.sendNotification(
              ownerDoc['fcmToken'], msg, "New Comment!", 'message');
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

  Future<void> _deleteComment(String commentId) async {
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(commentId)
        .delete();
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

        String mentionMsg = "$senderName mentioned you in a comment.";

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
          // 🌟 ၂။ Container ရဲ့ padding ထဲမှာ viewInsets ကို ဖြုတ်ပြီး ပုံမှန် 16 ပဲ ထားပါ
          padding: const EdgeInsets.only(
            bottom: 16,
            left: 16,
            right: 16,
            top: 16,
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
                        child: Text(
                          "no comments yet",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      );
                    }
                    // (ကျန်ရှိနေသော ဇယား သို့မဟုတ် List များကို ဆက်ရေးပါ)
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;

                        String commentUid = data['uid'] ?? '';
                        String name = data['userName'] ?? "Unknown User";
                        String avatar = data['userImage'] ?? "";
                        String commentText = data['text'] ?? "";
                        bool isEdited = data['isEdited'] ?? false;

                        bool canModify = (commentUid == currentUid) ||
                            (widget.postOwnerId == currentUid);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OtherProfilePage(
                                      userId: commentUid,
                                      userName: name,
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
                            title: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => OtherProfilePage(
                                      userId: commentUid,
                                      userName: name,
                                    ),
                                  ),
                                );
                              },
                              child: FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(commentUid)
                                    .get(),
                                builder: (context, snapshot) {
                                  String role = 'member';
                                  if (snapshot.hasData &&
                                      snapshot.data!.exists) {
                                    var commentUserData = snapshot.data!.data()
                                        as Map<String, dynamic>;
                                    role = commentUserData['role'] ?? 'member';
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
                                        const Text("(edited)",
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 10)),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                commentText,
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                            trailing: canModify
                                ? PopupMenuButton<String>(
                                    color: isDark
                                        ? const Color(0xFF1E1E1E)
                                            .withOpacity(0.9)
                                        : Colors.white.withOpacity(0.9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.15)
                                            : Colors.grey.withOpacity(0.2),
                                        width: 1.0,
                                      ),
                                    ),
                                    icon: Icon(Icons.more_vert,
                                        size: 18,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        setState(() {
                                          _isEditing = true;
                                          _editingCommentId = doc.id;
                                          _commentController.text = commentText;
                                        });
                                      } else if (value == 'delete') {
                                        _deleteComment(doc.id);
                                      }
                                    },
                                    itemBuilder: (context) {
                                      final Color itemTextColor = isDark
                                          ? Colors.white70
                                          : Colors.black87;

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
                                                  "ပြင်ရန်",
                                                  style: TextStyle(
                                                      color: itemTextColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text(
                                                "ဖျက်ရန်",
                                                style: TextStyle(
                                                    color: Colors.red),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ];
                                    },
                                  )
                                : null,
                          ),
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
                    border: Border.all(
                        color:
                            isDark ? Colors.grey[700]! : Colors.grey.shade300),
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
                        onTap: () => _onUserSelected(userData),
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
                      const Text("Editing Comment...",
                          style: TextStyle(color: Colors.blue, fontSize: 12)),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _editingCommentId = null;
                            _commentController.clear();
                          });
                        },
                        child: const Text("Cancel",
                            style: TextStyle(color: Colors.red, fontSize: 12)),
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

class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const PostVideoPlayer(
      {super.key,
      required this.videoUrl,
      required userName,
      required profileImageUrl,
      required uid,
      required String postId,
      required role});

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

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
  _SliverAppBarDelegate(this._tabBar, Color cardBgColor,
      {this.backgroundColor});

  final TabBar _tabBar;
  final Color? backgroundColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor ?? Colors.transparent,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

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
