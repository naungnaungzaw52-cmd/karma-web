import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:karma/main.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'other_profile_page.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:karma/widgets/post_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  // ဖတ်ပြီးကြောင်း မှတ်သားရန် Function
  void _markAsRead(String currentUid) {
    FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUid)
        .where('isRead', isEqualTo: false)
        .get()
        .then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.update({'isRead': true});
      }
    });
  }

  // Post Detail ကို ပြပေးမည့် Function
  void _showPostDetail(BuildContext context, DocumentSnapshot post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: post.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    // Page ဖွင့်တာနဲ့ ဖတ်ပြီးသားဖြစ်အောင် လုပ်ခြင်း
    _markAsRead(currentUid);

    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');
    // 🌟 Theme အလိုက် Card အရောင် အမှန်တကယ် ပြောင်းလဲစေရန်
    Color cardColor;
    if (themeProvider.currentTheme == 'Default') {
      cardColor = Colors.white;
    } else if (themeProvider.currentTheme == 'Soft Rose' ||
        themeProvider.currentTheme == 'Sunset Glow') {
      cardColor = Colors.white.withOpacity(0.15); // Glassmorphism ပုံစံ
    } else {
      cardColor =
          Colors.black.withOpacity(0.3); // Dark/Gradient Theme များအတွက်
    }

    Color textColor = themeProvider.getTextColor();

    return Container(
      // Theme အလိုက် Background ပြောင်းရန်
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Transparent ထားမှသာ Decoration ပေါ်လာမည်
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return Text(
                isMm ? "သတိပေးချက်များ" : "Notifications",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('receiverId', isEqualTo: currentUid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined,
                                  size: 60,
                                  color:
                                      isDark ? Colors.grey[400] : Colors.grey),
                              const SizedBox(height: 10),
                              Text(
                                isMm
                                    ? "အသိပေးချက်များ မရှိသေးပါ"
                                    : "No notifications yet",
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.grey[300] : Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  }

                  // notification_page.dart ထဲရှိ StreamBuilder အောက်ပါ ListView.builder အပိုင်းကို ဤသို့ အစားထိုးနိုင်ပါသည်
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var noti = snapshot.data!.docs[index];
                      var notiData = noti.data() as Map<String, dynamic>;

                      bool isRead = notiData['isRead'] ?? false;
                      String? senderId = notiData['senderId'];
                      List<dynamic>? senderIds = notiData['senderIds'];

                      // 🌟 Notification ထဲမှာ သိမ်းပြီးသား senderAvatar ကို အရင်သုံးပါ (Latency ကို သက်သာစေရန်)
                      String? profileImageUrl = notiData['senderAvatar'];
                      String fullMessage = notiData['message'] ?? "";

                      String time = "";
                      if (notiData['createdAt'] != null) {
                        DateTime date = notiData['createdAt'].toDate();
                        time =
                            "${date.month}/${date.day}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
                      }

                      return FutureBuilder<DocumentSnapshot>(
                        future: senderId != null
                            ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(senderId)
                                .get()
                            : null,
                        builder: (context, userSnapshot) {
                          String userRole = 'member';
                          String senderName = "Unknown User";

                          if (userSnapshot.hasData &&
                              userSnapshot.data != null &&
                              userSnapshot.data!.exists) {
                            var userData = userSnapshot.data!.data()
                                as Map<String, dynamic>;
                            // User စာရင်းထဲက ပုံအသစ်နဲ့ နာမည်အသစ်ကိုပါ အတည်ပြုယူရန်
                            profileImageUrl =
                                userData['profileImageUrl'] ?? profileImageUrl;
                            userRole = userData['role'] ?? 'member';
                            senderName =
                                userData['displayName'] ?? "Unknown User";
                          }

                          bool isMm = isMyanmarNotifier.value;
                          String actionText = "";
                          if (senderIds != null && senderIds.length > 1) {
                            int otherCount = senderIds.length - 1;
                            actionText = isMm
                                ? "နှင့် အခြား $otherCount ယောက်က သင့် Post ကို Like ပေးပါတယ်။"
                                : " and $otherCount others liked your post.";
                          } else {
                            // 🌟 ဤနေရာတွင် အောက်ပါ အသစ်ပြင်ဆင်ထားသော Logic ကို ထည့်ပါ 🌟
                            String notiType = notiData['type'] ?? '';

                            if (notiType == 'follow') {
                              actionText = isMm
                                  ? "started following you."
                                  : " started following you.";
                            } else if (notiType == 'like') {
                              actionText = isMm
                                  ? "က သင့် Post ကို Like ပေးပါတယ်။"
                                  : " liked your post.";
                            } else if (notiType == 'comment') {
                              String rawMsg = notiData['message'] ?? "";
                              if (isMm && rawMsg.contains("က ")) {
                                int indexOfKa = rawMsg.indexOf("က ");
                                actionText = rawMsg.substring(indexOfKa);
                              } else if (!isMm) {
                                actionText = " commented on your post.";
                              } else {
                                actionText =
                                    "က သင့် Post ကို Comment ပေးသွားပါတယ်။";
                              }
                            } else {
                              actionText = fullMessage;
                              if (senderName.isNotEmpty &&
                                  actionText.startsWith(senderName)) {
                                actionText = actionText
                                    .replaceFirst(senderName, "")
                                    .trim();
                              }
                              if (actionText.isEmpty) {
                                actionText = isMm
                                    ? "က သင့်ထံသို့ အကြောင်းကြားချက် ပို့ထားပါသည်။"
                                    : " sent you a notification.";
                              }
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? cardColor
                                  : (isDark
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(isDark ? 0.3 : 0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              onTap: () async {
                                if (notiData.containsKey('postId') &&
                                    notiData['postId'] != null) {
                                  String postId = notiData['postId'];
                                  var postDoc = await FirebaseFirestore.instance
                                      .collection('posts')
                                      .doc(postId)
                                      .get();
                                  if (postDoc.exists) {
                                    if (!context.mounted) return;
                                    _showPostDetail(context, postDoc);
                                  }
                                } else if (senderId != null) {
                                  var userDoc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(senderId)
                                      .get();

                                  if (userDoc.exists) {
                                    if (!context.mounted) return;
                                    var userData =
                                        userDoc.data() as Map<String, dynamic>;
                                    String navSenderName =
                                        userData['displayName'] ??
                                            "Unknown User";

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OtherProfilePage(
                                          userId: senderId,
                                          userName: navSenderName,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.blue.withOpacity(0.1),
                                backgroundImage: (profileImageUrl != null &&
                                        profileImageUrl!.isNotEmpty)
                                    ? NetworkImage(profileImageUrl!)
                                    : null,
                                child: (profileImageUrl == null ||
                                        profileImageUrl!.isEmpty)
                                    ? const Icon(Icons.person,
                                        color: Colors.blueAccent)
                                    : null,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        GoldenNameWidget(
                                          name: senderName,
                                          role: userRole,
                                          fontSize: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          actionText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  time,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey),
                                ),
                              ),
                              trailing: !isRead
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
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
  }
}
