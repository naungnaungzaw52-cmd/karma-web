// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:karma/main.dart';
import 'package:karma/pages/search_page.dart';
import 'package:karma/services/notification_service.dart';
import 'package:karma/widgets/full_screen_gallery.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'banner_ad_widget.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:karma/pages/other_profile_page.dart';
import 'package:karma/utilis/navigation_helper.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

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

  Future<void> _toggleLike(String postId, List likes, String ownerId) async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    var postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    String userName =
        FirebaseAuth.instance.currentUser?.displayName ?? "အသုံးပြုသူ";

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

    if (likes.contains(uid)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([uid]),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([uid]),
        'likesCount': FieldValue.increment(1),
      });

      if (uid != ownerId) {
        String msg = "$userName liked your post.";

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

  // 🌟 Tip ပေးမည့် Modal (OtherProfilePage မှ ယူသုံးထားသည်)
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

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDarkTheme = themeProvider.currentTheme != 'Default';

    Color textColor = themeProvider.getTextColor();
    Color subTextColor = isDarkTheme ? Colors.grey[400]! : Colors.grey[700]!;

    Color cardColor;
    if (themeProvider.currentTheme == 'Default') {
      cardColor = Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      cardColor = Colors.white.withOpacity(0.15);
    } else {
      cardColor = Colors.black.withOpacity(0.3);
    }

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
                isMm ? 'ပို့စ်အသေးစိတ်' : 'Post Details',
                style: TextStyle(color: textColor),
              );
            },
          ),
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Column(
          children: [
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Center(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Text(
                            isMm
                                ? 'ဤပို့စ်ကို မတွေ့ရှိတော့ပါ။'
                                : 'This post no longer exists.',
                            style: TextStyle(color: textColor),
                          );
                        },
                      ),
                    );
                  }

                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  List likes = data['likes'] ?? [];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(10.0),
                    child: Card(
                      color: cardColor,
                      margin: EdgeInsets.zero,
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDarkTheme
                              ? Colors.white.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.2),
                          width: 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                NavigationHelper.push(
                                  context,
                                  OtherProfilePage(
                                    userId: data['uid'],
                                    userName: data['userName'] ?? "unknown",
                                  ),
                                );
                              },
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: data['userImage'] != null &&
                                          data['userImage']
                                              .toString()
                                              .isNotEmpty
                                      ? NetworkImage(data['userImage'])
                                      : null,
                                  child: data['userImage'] == null ||
                                          data['userImage'].toString().isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
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
                                      var postUserData = userSnapshot.data!
                                          .data() as Map<String, dynamic>;
                                      role = postUserData['role'] ?? 'member';
                                    }

                                    return GoldenNameWidget(
                                      name: data['userName'] ?? "unknown",
                                      role: role,
                                      fontSize: 16,
                                      isWhiteBackground: !isDarkTheme,
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
                                    color: subTextColor,
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
                                        style: TextStyle(
                                            fontSize: 15, color: textColor),
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
                                child:
                                    PostAudioPlayer(audioUrl: data['audioUrl']),
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
                                      _toggleLike(postId, likes, data['uid']),
                                ),
                                Text("${likes.length}",
                                    style: TextStyle(
                                        fontSize: 13, color: subTextColor)),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: Icon(Icons.comment_outlined,
                                      size: 22, color: textColor),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 10, sigmaY: 10),
                                        child: _CommentBottomSheet(
                                          postId: postId,
                                          postOwnerId: data['uid'],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Text(
                                  "${data['commentsCount'] ?? 0}",
                                  style: TextStyle(
                                      fontSize: 13, color: subTextColor),
                                ),
                                const SizedBox(width: 16),
                                // 🌟 Tip ဖန်ရှင် ခလုတ်နှင့် တောက်ထွက်နေသော totalTips အရေအတွက်
                                GestureDetector(
                                  onTap: () {
                                    showTipModal(
                                      context,
                                      data['uid'],
                                      data['userName'] ?? "unknown",
                                      postId,
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
                                        color: subTextColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${data['viewCount'] ?? 0}",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: subTextColor,
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

    // 🌟 1. ဗီဒီယို တစ်ခုတည်းရှိလျှင် Aspect Ratio ဖြင့် ညီညာစွာပြသရန်
    if (!_isImageUrl(mediaUrls[0]) && mediaUrls.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PostVideoPlayer(videoUrl: mediaUrls[0]),
          ),
        ),
      );
    }

    // 🌟 2. ပုံ တစ်ပုံတည်းရှိလျှင် မူရင်းအချိုးအစားအတိုင်း အပြည့်ပြရန်
    if (mediaUrls.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenGalleryScreen(
                  mediaUrls: mediaUrls, initialIndex: 0),
            ),
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
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return Text(
                        isMm ? "ပုံဖွင့်၍မရပါ" : "Failed to load image",
                        style: const TextStyle(color: Colors.white),
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenGalleryScreen(
                      mediaUrls: mediaUrls, initialIndex: index),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    mediaUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Text(
                            isMm ? "ပုံအမှား" : "Image Error",
                            style: const TextStyle(color: Colors.white),
                          );
                        },
                      ),
                    ),
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

// ---------------------------------------------
// Comment BottomSheet (User 10 comments limit logic included)
// ---------------------------------------------
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
      // 🌟 ဤပို့စ်တွင် ဤအသုံးပြုသူ (currentUid) မှ Comment ၁၀ ခုထက် ပိုရေးထားပြီးပြီလား စစ်ဆေးခြင်း
      var existingComments = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .where('uid', isEqualTo: currentUid)
          .get();

      if (existingComments.docs.length >= 10) {
        final isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? "ဤပို့စ်တွင် Comment ၁၀ ခုသာ အများဆုံး ပေးခွင့်ရှိပါသည်။"
                  : "Maximum of 10 comments are allowed per post.",
            ),
          ),
        );
        return;
      }

      String userName = currentUser?.displayName ?? "အသုံးပြုသူ";

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
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
        'commentsCount': FieldValue.increment(1),
      });
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
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({
      'commentsCount': FieldValue.increment(-1),
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
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    // 🌟 ၁။ Padding ကို အပြင်ဘက်မှာ အရင်ခံပေးပါ
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
                    // (ကျန်ရှိနေသော ဇယား သို့မဟုတ် List များကို ဆက်ရေးပါ)
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
                          leading: CircleAvatar(
                            backgroundImage:
                                avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: FutureBuilder<DocumentSnapshot>(
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
                                            fontSize: 10,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(commentText,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87)),
                          ),
                          trailing: canModify
                              ? PopupMenuButton<String>(
                                  color: isDark
                                      ? const Color(0xFF1E1E1E).withOpacity(0.9)
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
                                    final bool isMm = isMyanmarNotifier.value;
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
                                                  size: 16, color: Colors.blue),
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
                                              style: const TextStyle(
                                                  color: Colors.red),
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
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return Row(
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
                      );
                    },
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
// PostVideoPlayer (HTML Video Player with WebView)
// -------------------------------------------------------------
class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const PostVideoPlayer({super.key, required this.videoUrl});

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
