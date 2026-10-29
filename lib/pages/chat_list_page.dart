// ignore_for_file: avoid_print

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;
import 'package:karma/main.dart';
import 'package:karma/pages/profile_page.dart';
import 'package:karma/services/r2_service.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:karma/widgets/story_view_widget.dart';
import 'chat_page.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  Future<void> _clearEntireChat(String chatId) async {
    try {
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (var doc in messagesSnapshot.docs) {
        final data = doc.data();
        final String? fileUrl = data['fileUrl'];

        if (fileUrl != null && fileUrl.isNotEmpty) {
          try {
            await R2Service.deleteFile(fileUrl);
          } catch (e) {
            print('R2 ဖိုင်ဖျက်ရာတွင် အမှားဖြစ်ပေါ်သည်: $e');
          }
        }
        batch.delete(doc.reference);
      }

      batch.delete(FirebaseFirestore.instance.collection('chats').doc(chatId));
      await batch.commit();
    } catch (e) {
      print('ချတ်ဖျက်ဆီးခြင်း မအောင်မြင်ပါ: $e');
    }
  }

  Future<void> _blockUser(String currentUid, String targetUserId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({
        'blockedUsers': FieldValue.arrayUnion([targetUserId])
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMyanmarNotifier.value
                  ? "အသုံးပြုသူကို အောင်မြင်စွာ Block လိုက်ပါပြီ။"
                  : "User has been blocked successfully.",
            ),
          ),
        );
      }
    } catch (e) {
      print('Block ရာတွင် အမှားဖြစ်ပေါ်သည်: $e');
    }
  }

  Future<void> _reportUser(
      String currentUid, String targetUserId, String reason) async {
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedBy': currentUid,
        'reportedUser': targetUserId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMyanmarNotifier.value
                  ? "တိုင်ကြားချက်ကို လက်ခံရရှိပါပြီ။"
                  : "Report submitted.",
            ),
          ),
        );
      }
    } catch (e) {
      print('Report တင်ရာတွင် အမှားဖြစ်ပေါ်သည်: $e');
    }
  }

  void _showChatOptionsModal(
      BuildContext context,
      String chatId,
      Map<String, dynamic> chatData,
      String currentUid,
      String targetUserId) async {
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();
    String role = userDoc.exists
        ? (userDoc.data() as Map<String, dynamic>)['role'] ?? 'member'
        : 'member';

    bool isGoldOrVip = role == 'gold_user' ||
        role == 'vip' ||
        role == 'gold' ||
        role == 'admin';

    List pinnedBy = chatData['pinnedBy'] ?? [];
    bool isPinned = pinnedBy.contains(currentUid);
    bool isGroup = chatData['isGroup'] ?? false;

    if (!context.mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();
    Color sheetBgColor = isDark
        ? const Color(0xFF1E1E1E).withOpacity(0.65)
        : Colors.white.withOpacity(0.65);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBgColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.5),
                width: 1.0,
              ),
            ),
            child: SafeArea(
              child: Wrap(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return ListTile(
                        leading: Icon(
                            isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                            color: Colors.blue),
                        title: Text(
                          isPinned
                              ? (isMm ? "Pin ဖြုတ်မည်" : "Unpin")
                              : (isMm ? "Pin လုပ်မည်" : "Pin to Top"),
                          style: TextStyle(color: textColor),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          if (!isPinned) {
                            var pinnedChatsQuery = await FirebaseFirestore
                                .instance
                                .collection('chats')
                                .where('pinnedBy', arrayContains: currentUid)
                                .get();

                            if (pinnedChatsQuery.docs.length >= 3 &&
                                !isGoldOrVip) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isMm
                                        ? "ပုံမှန်အသုံးပြုသူများသည် Pin ၃ ခုသာ ထားရှိနိုင်ပါသည်။"
                                        : "Standard users can only pin up to 3 chats.",
                                  ),
                                ),
                              );
                              return;
                            }

                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatId)
                                .update({
                              'pinnedBy': FieldValue.arrayUnion([currentUid]),
                            });
                          } else {
                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatId)
                                .update({
                              'pinnedBy': FieldValue.arrayRemove([currentUid]),
                            });
                          }
                        },
                      );
                    },
                  ),
                  if (!isGroup && targetUserId.isNotEmpty)
                    ValueListenableBuilder<bool>(
                      valueListenable: isMyanmarNotifier,
                      builder: (context, isMm, child) {
                        return ListTile(
                          leading:
                              const Icon(Icons.block, color: Colors.orange),
                          title: Text(
                            isMm ? "ဤအသုံးပြုသူကို Block မည်" : "Block User",
                            style: const TextStyle(color: Colors.orange),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            bool? confirm = await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  backgroundColor: isDark
                                      ? const Color(0xFF2C2C2C)
                                      : Colors.white,
                                  title: Text(
                                    isMm ? "Block ပြုလုပ်ရန်" : "Block User",
                                    style: TextStyle(color: textColor),
                                  ),
                                  content: Text(
                                    isMm
                                        ? "ဤအသုံးပြုသူကို Block ရန် သေချာပါသလား?"
                                        : "Are you sure you want to block this user?",
                                    style: TextStyle(color: textColor),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(isMm ? "မလုပ်ပါ" : "Cancel",
                                          style: TextStyle(color: textColor)),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        isMm ? "Block မည်" : "Block",
                                        style: const TextStyle(
                                            color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              await _blockUser(currentUid, targetUserId);
                            }
                          },
                        );
                      },
                    ),
                  if (!isGroup && targetUserId.isNotEmpty)
                    ValueListenableBuilder<bool>(
                      valueListenable: isMyanmarNotifier,
                      builder: (context, isMm, child) {
                        return ListTile(
                          leading:
                              const Icon(Icons.flag, color: Colors.deepOrange),
                          title: Text(
                            isMm ? "တိုင်ကြားမည် (Report)" : "Report User",
                            style: const TextStyle(color: Colors.deepOrange),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            _showReportDialog(
                                context, currentUid, targetUserId, isMm);
                          },
                        );
                      },
                    ),
                  ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return ListTile(
                        leading:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        title: Text(
                          isMm
                              ? "ဤ Chat ကို အကုန်ဖျက်မည်"
                              : "Delete Entire Chat",
                          style: const TextStyle(color: Colors.red),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          bool? confirm = await showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                backgroundColor: isDark
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.white,
                                title: Text(
                                  isMm ? "Chat ဖျက်ရန်" : "Delete Chat",
                                  style: TextStyle(color: textColor),
                                ),
                                content: Text(
                                  isMm
                                      ? "ဤ Chat တစ်ခုလုံးကို အပြီးအပိုင် ဖျက်မှာ သေချာပါသလား?"
                                      : "Are you sure you want to delete this entire chat?",
                                  style: TextStyle(color: textColor),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(isMm ? "မလုပ်ပါ" : "Cancel",
                                        style: TextStyle(color: textColor)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(
                                      isMm ? "ဖျက်မည်" : "Delete",
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirm == true) {
                            await _clearEntireChat(chatId);
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReportDialog(
      BuildContext context, String currentUid, String targetUserId, bool isMm) {
    TextEditingController reasonController = TextEditingController();
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        title: Text(
          isMm ? "တိုင်ကြားစာ ပေးပို့ရန်" : "Report User",
          style: TextStyle(color: textColor),
        ),
        content: TextField(
          controller: reasonController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: isMm
                ? "တိုင်ကြားရသည့် အကြောင်းအရင်း ရေးပါ..."
                : "Enter reason...",
            hintStyle:
                TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isMm ? "မလုပ်ပါ" : "Cancel",
                style: TextStyle(color: textColor)),
          ),
          TextButton(
            onPressed: () async {
              String reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                Navigator.pop(context);
                await _reportUser(currentUid, targetUserId, reason);
              }
            },
            child: Text(isMm ? "ပို့မည်" : "Submit",
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentUid = FirebaseAuth.instance.currentUser!.uid;

    final themeProvider = Provider.of<ThemeProvider>(context);

    Color textColor = (themeProvider.currentTheme == 'Default')
        ? Colors.black87
        : Colors.white;
    Color subtitleColor = (themeProvider.currentTheme == 'Default')
        ? Colors.grey[700]!
        : Colors.white70;

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.cyclone, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                "Messenger",
                style: TextStyle(
                  color: themeProvider.getTextColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUid)
                  .snapshots(),
              builder: (context, snapshot) {
                String profileImage = '';
                if (snapshot.hasData && snapshot.data!.exists) {
                  var myData = snapshot.data!.data() as Map<String, dynamic>;
                  profileImage = myData['profileImageUrl'] ??
                      myData['profileImage'] ??
                      myData['photoURL'] ??
                      '';
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfilePage(),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blueAccent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundImage: profileImage.isNotEmpty
                              ? NetworkImage(profileImage)
                              : null,
                          child: profileImage.isEmpty
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            const StoryViewWidget(),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .snapshots(),
                builder: (context, userDocSnapshot) {
                  List blockedUsers = [];
                  if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                    var userData =
                        userDocSnapshot.data!.data() as Map<String, dynamic>?;
                    if (userData != null && userData['blockedUsers'] is List) {
                      blockedUsers = userData['blockedUsers'];
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chats')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var allDocs = snapshot.data!.docs;
                      var myChats = allDocs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        List? participants = data['participants'];
                        List? members = data['members'];
                        bool isGroup = data['isGroup'] ?? false;

                        bool inParticipants = participants != null &&
                            participants.contains(currentUid);
                        bool inMembers =
                            members != null && members.contains(currentUid);

                        if (participants != null && !isGroup) {
                          String otherUserId = participants.firstWhere(
                              (id) => id != currentUid,
                              orElse: () => "");
                          if (blockedUsers.contains(otherUserId)) {
                            return false;
                          }
                        }

                        return inParticipants || inMembers;
                      }).toList();

                      myChats.sort((a, b) {
                        var dataA = a.data() as Map<String, dynamic>;
                        var dataB = b.data() as Map<String, dynamic>;

                        List pinnedA = dataA['pinnedBy'] ?? [];
                        List pinnedB = dataB['pinnedBy'] ?? [];

                        bool isPinnedA = pinnedA.contains(currentUid);
                        bool isPinnedB = pinnedB.contains(currentUid);

                        if (isPinnedA && !isPinnedB) return -1;
                        if (!isPinnedA && isPinnedB) return 1;

                        Timestamp? timeA = dataA['lastTimestamp'] ??
                            dataA['lastMessageTime'] ??
                            dataA['updatedAt'];
                        Timestamp? timeB = dataB['lastTimestamp'] ??
                            dataB['lastMessageTime'] ??
                            dataB['updatedAt'];

                        if (timeA == null && timeB == null) return 0;
                        if (timeA == null) return 1;
                        if (timeB == null) return -1;

                        return timeB.compareTo(timeA);
                      });

                      if (myChats.isEmpty) {
                        return Center(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: isMyanmarNotifier,
                            builder: (context, isMm, child) {
                              return Text(
                                isMm
                                    ? "စကားပြောဆိုမှုများ မရှိသေးပါ။"
                                    : "No conversations yet.",
                                style: TextStyle(color: textColor),
                              );
                            },
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: myChats.length,
                        itemBuilder: (context, index) {
                          var chat = myChats[index];
                          var chatData = chat.data() as Map<String, dynamic>;

                          bool isGroup = chatData['isGroup'] ?? false;
                          String chatId = chat.id;

                          List pinnedBy = chatData['pinnedBy'] ?? [];
                          bool isPinned = pinnedBy.contains(currentUid);

                          if (isGroup) {
                            bool isMm = isMyanmarNotifier.value;
                            String groupName = chatData['groupName'] ??
                                (isMm ? "အဖွဲ့လိုက် ချတ်" : "Group Chat");
                            String lastMessage = chatData['lastMessage'] ??
                                (isMm ? "စာစတင်ပေးပို့ပါ" : "Start messaging");
                            String? groupImageUrl = chatData['groupImage'];

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('chats')
                                  .doc(chatId)
                                  .collection('messages')
                                  .where('isRead', isEqualTo: false)
                                  .snapshots(),
                              builder: (context, msgSnapshot) {
                                int unreadCount = 0;
                                if (msgSnapshot.hasData) {
                                  unreadCount =
                                      msgSnapshot.data!.docs.where((doc) {
                                    var msgData =
                                        doc.data() as Map<String, dynamic>;
                                    String senderId = msgData['senderId'] ?? '';
                                    var receiverId = msgData['receiverId'];

                                    bool isForGroup = (receiverId == null ||
                                        receiverId == '');
                                    return senderId != currentUid && isForGroup;
                                  }).length;
                                }

                                return ListTile(
                                  trailing: isPinned
                                      ? const Icon(Icons.push_pin,
                                          size: 16, color: Colors.blue)
                                      : null,
                                  leading: badges.Badge(
                                    showBadge: unreadCount > 0,
                                    badgeContent: Text("$unreadCount",
                                        style: const TextStyle(
                                            color: Colors.white)),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.blueGrey,
                                      backgroundImage: groupImageUrl != null &&
                                              groupImageUrl.isNotEmpty
                                          ? NetworkImage(groupImageUrl)
                                          : null,
                                      child: groupImageUrl == null ||
                                              groupImageUrl.isEmpty
                                          ? const Icon(Icons.group,
                                              color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  title: Text(
                                    groupName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    lastMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: subtitleColor,
                                    ),
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatPage(
                                        receiverId: chatId,
                                        receiverName: groupName,
                                        isGroup: true,
                                        chatIdOverride: chatId,
                                      ),
                                    ),
                                  ),
                                  onLongPress: () => _showChatOptionsModal(
                                      context,
                                      chatId,
                                      chatData,
                                      currentUid,
                                      ""),
                                );
                              },
                            );
                          } else {
                            List participants = chatData['participants'] ?? [];
                            String receiverId = participants.firstWhere(
                                (id) => id != currentUid,
                                orElse: () => "");

                            if (receiverId.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            List<String> ids = [currentUid, receiverId];
                            ids.sort();
                            String directChatId = ids.join("_");

                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(receiverId)
                                  .snapshots(),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData ||
                                    !userSnapshot.data!.exists) {
                                  return const SizedBox.shrink();
                                }
                                var userData = userSnapshot.data!.data()
                                    as Map<String, dynamic>;
                                bool isOnline = userData['isOnline'] ?? false;

                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('chats')
                                      .doc(directChatId)
                                      .collection('messages')
                                      .where('isRead', isEqualTo: false)
                                      .where('receiverId',
                                          isEqualTo: currentUid)
                                      .snapshots(),
                                  builder: (context, msgSnapshot) {
                                    int unreadCount = msgSnapshot.hasData
                                        ? msgSnapshot.data!.docs.length
                                        : 0;

                                    return ListTile(
                                      trailing: isPinned
                                          ? const Icon(Icons.push_pin,
                                              size: 16, color: Colors.blue)
                                          : null,
                                      leading: Stack(
                                        children: [
                                          badges.Badge(
                                            showBadge: unreadCount > 0,
                                            badgeContent: Text("$unreadCount",
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                            child: CircleAvatar(
                                              radius: 24,
                                              backgroundImage: NetworkImage(
                                                  userData['profileImageUrl'] ??
                                                      ""),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isOnline
                                                    ? Colors.green
                                                    : Colors.grey,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      title: GoldenNameWidget(
                                        name: userData['displayName'] ??
                                            (isMyanmarNotifier.value
                                                ? "အသုံးပြုသူ"
                                                : "User"),
                                        role: userData['role'],
                                        fontSize: 16,
                                      ),
                                      subtitle: Text(
                                        chatData['lastMessage'] ??
                                            (isMyanmarNotifier.value
                                                ? "စာစတင်ပေးပို့ပါ"
                                                : "Start messaging"),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: subtitleColor),
                                      ),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatPage(
                                            receiverId: receiverId,
                                            receiverName:
                                                userData['displayName'] ??
                                                    (isMyanmarNotifier.value
                                                        ? "အသုံးပြုသူ"
                                                        : "User"),
                                            isGroup: false,
                                          ),
                                        ),
                                      ),
                                      onLongPress: () => _showChatOptionsModal(
                                          context,
                                          chatId,
                                          chatData,
                                          currentUid,
                                          receiverId),
                                    );
                                  },
                                );
                              },
                            );
                          }
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
