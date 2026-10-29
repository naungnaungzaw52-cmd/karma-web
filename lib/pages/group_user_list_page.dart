// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:karma/main.dart';
import 'package:karma/services/notification_service.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:provider/provider.dart'; // 👈 Import Provider
import 'package:karma/utilis/theme_provider.dart'; // 👈 Import ThemeProvider

class GroupUserListPage extends StatefulWidget {
  final String chatId;
  final bool isAdmin;

  const GroupUserListPage({
    super.key,
    required this.chatId,
    required this.isAdmin,
  });

  @override
  State<GroupUserListPage> createState() => _GroupUserListPageState();
}

class _GroupUserListPageState extends State<GroupUserListPage> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  // Member တစ်ယောက်ကို Group ထဲမှ ဖယ်ရှားရန် (Admin အတွက်)
  void _removeMember(String memberId, String memberName) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return AlertDialog(
                title: Text(isMm ? 'အဖွဲ့ဝင်ကို ဖယ်ရှားရန်' : 'Remove Member'),
                content: Text(
                  isMm
                      ? '$memberName ကို ဒီ Group ထဲကနေ ဖယ်ရှားမှာ သေချာပါသလား?'
                      : 'Are you sure you want to remove $memberName from this group?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(isMm ? 'မလုပ်ပါ' : 'Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      isMm ? 'ဖယ်ရှားမည်' : 'Remove',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      var docRef =
          FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      var doc = await docRef.get();

      if (doc.exists) {
        List<dynamic> members = doc['members'] ?? [];
        members.remove(memberId);

        List<dynamic> admins = doc['adminIds'] ?? [];
        admins.remove(memberId);

        await docRef.update({
          'members': members,
          'adminIds': admins,
        });

        if (!mounted) return;
        bool isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? '$memberName ကို အဖွဲ့မှ ဖယ်ရှားပြီးပါပြီ'
                  : '$memberName has been removed from the group.',
            ),
          ),
        );
      }
    } catch (e) {
      print("Error removing member: $e");
    }
  }

  // 🚪 Member ကိုယ်တိုင် Group မှ ထွက်ခွာခြင်း (Leave Group & Notify Admins)
  void _leaveGroup() async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) => ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return AlertDialog(
                title: Text(isMm ? 'အဖွဲ့မှ ထွက်ခွာရန်' : 'Leave Group'),
                content: Text(
                  isMm
                      ? 'ဒီ Group ထဲကနေ ထွက်မှာ သေချာပါသလား?'
                      : 'Are you sure you want to leave this group?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(isMm ? 'မလုပ်ပါ' : 'Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      isMm ? 'ထွက်မည်' : 'Leave',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      var docRef =
          FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      var doc = await docRef.get();

      if (doc.exists) {
        List<dynamic> members = doc['members'] ?? [];
        List<dynamic> admins = doc['adminIds'] ?? [];

        // ကိုယ့် ID ကို members နဲ့ admins စာရင်းထဲက ဖြုတ်မည်
        members.remove(currentUid);
        admins.remove(currentUid);

        await docRef.update({
          'members': members,
          'adminIds': admins,
        });

        // ထွက်သွားသူ၏ အချက်အလက်ကို ဆွဲထုတ်ရန်
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get();

        bool isMm = isMyanmarNotifier.value;
        String userName = isMm ? "အသုံးပြုသူ" : "User";
        String senderAvatar = '';
        if (userDoc.exists) {
          var uData = userDoc.data() as Map<String, dynamic>?;
          userName = uData?['name'] ?? uData?['displayName'] ?? userName;
          senderAvatar = uData?['profileImageUrl'] ?? '';
        }

        String msg = isMm
            ? "$userName က Group မှ ထွက်သွားပါပြီ။"
            : "$userName has left the group.";

        // Admin တစ်ဦးချင်းစီဆီသို့ Notification ပို့ရန်
        for (var adminId in admins) {
          if (adminId != currentUid) {
            // Firestore notifications collection ထဲသို့ မှတ်တမ်းတင်ရန်
            await FirebaseFirestore.instance.collection('notifications').add({
              'receiverId': adminId,
              'senderId': currentUid,
              'senderAvatar': senderAvatar,
              'chatId': widget.chatId,
              'message': msg,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });

            // Admin ရဲ့ FCM Token ရှိမရှိ စစ်ဆေးပြီး Push Notification ပို့ရန်
            DocumentSnapshot adminDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(adminId)
                .get();

            if (adminDoc.exists) {
              var adminData = adminDoc.data() as Map<String, dynamic>?;
              if (adminData != null && adminData['fcmToken'] != null) {
                NotificationService.sendNotification(
                    adminData['fcmToken'], msg, "Group Member Left", 'message');
              }
            }
          }
        }

        // Group မျက်နှာပြင်မှ ထွက်ရန် (Previous Screen သို့ ပြန်သွားမည်)
        Navigator.pop(context); // Dialog ပိတ်ရန်
        Navigator.pop(context); // Group ထဲမှ ထွက်ရန်

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? 'အဖွဲ့မှ အောင်မြင်စွာ ထွက်ခွာခဲ့ပြီးပါပြီ'
                  : 'Successfully left the group.',
            ),
          ),
        );
      }
    } catch (e) {
      print("Error leaving group: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ThemeProvider ကို ခေါ်သုံးပါ
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDarkMode = (themeProvider.currentTheme != 'Default');
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      // 1. AppBar အရောင်ကို Theme နဲ့ လိုက်လျောညီထွေဖြစ်အောင်ပြင်ပါ
      appBar: AppBar(
        title: ValueListenableBuilder<bool>(
          valueListenable: isMyanmarNotifier,
          builder: (context, isMm, child) {
            return Text(
              isMm ? 'Group အဖွဲ့ဝင်များ' : 'Group Members',
              style: TextStyle(color: textColor),
            );
          },
        ),
        backgroundColor: isDarkMode ? Colors.black87 : Colors.white,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return IconButton(
                icon: Icon(Icons.exit_to_app,
                    color: isDarkMode ? Colors.redAccent : Colors.red),
                tooltip: isMm ? "အဖွဲ့မှ ထွက်ရန်" : "Leave Group",
                onPressed: _leaveGroup,
              );
            },
          ),
        ],
      ),
      // 2. Background ကို ThemeProvider ကနေ ယူသုံးပါ
      body: Container(
        decoration: themeProvider.getBackgroundDecoration(),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: CircularProgressIndicator());
            }

            var chatData = snapshot.data!.data() as Map<String, dynamic>;
            List<dynamic> memberIds = chatData['members'] ?? [];
            List<dynamic> adminIds = chatData['adminIds'] ?? [];

            return ListView.builder(
              itemCount: memberIds.length,
              itemBuilder: (context, index) {
                String memberId = memberIds[index];

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(memberId)
                      .get(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }

                    var userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    String userName = userData['name'] ??
                        userData['displayName'] ??
                        'အမည်မရှိ';
                    String? userAvatar = userData['profileImageUrl'];
                    bool isUserAdmin = adminIds.contains(memberId);
                    String memberRole =
                        userData['role'] ?? (isUserAdmin ? 'Admin' : 'Member');

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userAvatar != null &&
                                userAvatar.isNotEmpty
                            ? NetworkImage(userAvatar)
                            : const NetworkImage(
                                "https://cdn-icons-png.flaticon.com/512/3135/3135768.png"),
                      ),
                      // GoldenNameWidget က ThemeProvider နဲ့ ချိတ်ထားပြီးသားမို့ အလိုအလျောက် အရောင်ပြောင်းပါလိမ့်မယ်
                      title: GoldenNameWidget(
                          name: userName, role: memberRole, fontSize: 16),
                      subtitle: Text(
                        isUserAdmin ? "👑 Admin" : "Member",
                        style: TextStyle(
                          color: isUserAdmin
                              ? Colors.orange
                              : (isDarkMode ? Colors.white70 : Colors.grey),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: (widget.isAdmin &&
                              memberId != currentUid &&
                              !isUserAdmin)
                          ? IconButton(
                              icon: Icon(Icons.remove_circle,
                                  color: isDarkMode
                                      ? Colors.redAccent
                                      : Colors.red),
                              onPressed: () =>
                                  _removeMember(memberId, userName),
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
    );
  }
}
