// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart'; // kIsWeb အတွက် လိုအပ်သည်
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:badges/badges.dart' as badges;
// 🌟 Web အတွက် CallKit ကို kIsWeb ဖြင့် ထိန်းချုပ်မည်
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:karma/services/call_service.dart';
import 'pages/home_page.dart';
import 'pages/rewards_page.dart';
import 'pages/notification_page.dart';
import 'pages/profile_page.dart';
import 'pages/chat_list_page.dart';
import 'pages/call_screen.dart';
import 'pages/chat_page.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  final CallService _callService = CallService();

  StreamSubscription? _callDocSub;

  // 🌈 Rainbow Glow Animation အတွက် Controller
  late AnimationController _rainbowController;

  final List<Widget> _pages = [
    const HomePage(),
    const RewardsPage(),
    const ChatListPage(),
    const NotificationPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // 🌟 Web မဟုတ်မှသာ CallKit နှင့် Native များကို စစ်ဆေးမည်
    if (!kIsWeb) {
      _checkCallKitEvents();
      _checkInitialCall();
    }
    _setupForegroundMessageListener();
    _setupMessageClickListeners();

    // Animation Controller စတင်ခြင်း
    _rainbowController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _callDocSub?.cancel();
    _rainbowController.dispose();
    super.dispose();
  }

  void _listenToSpecificCall(String callId, String callerName) {
    _callDocSub?.cancel();

    _callDocSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((docSnapshot) async {
      if (docSnapshot.exists) {
        var data = docSnapshot.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';

        if (status == 'ended' || status == 'rejected') {
          if (!kIsWeb) {
            await FlutterCallkitIncoming.endAllCalls();
          }
          _callDocSub?.cancel();
        }
      }
    });
  }

  void _setupForegroundMessageListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'call') {
        String callId = message.data['callId'] ?? '';
        String callerName = message.data['callerName'] ?? 'အမည်မသိ';
        String callerAvatar = message.data['callerAvatar'] ??
            'https://cdn-icons-png.flaticon.com/512/3135/3135768.png';

        _listenToSpecificCall(callId, callerName);

        // 🌟 Web တွင် CallKit မသုံးဘဲ App ထဲမှသာ Notification/UI ပြရန် (လိုအပ်ပါက ဖြည့်စွက်နိုင်သည်)
        if (!kIsWeb) {
          CallKitParams callKitParams = CallKitParams(
            id: callId,
            nameCaller: callerName,
            appName: 'Karma',
            avatar: callerAvatar,
            handle: 'Incoming Video Call',
            type: 1,
            duration: 30000,
            textAccept: 'လက်ခံမည်',
            textDecline: 'ငြင်းပယ်မည်',
            extra: {'callId': callId},
            android: const AndroidParams(
              isCustomNotification: true,
              ringtonePath: 'ringtone',
            ),
          );
          FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
        }
      }
    });
  }

  void _setupMessageClickListeners() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'message' ||
          message.data['senderId'] != null) {
        _navigateToChat(message.data);
      }
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        if (message.data['type'] == 'message' ||
            message.data['senderId'] != null) {
          Future.delayed(const Duration(milliseconds: 600), () {
            _navigateToChat(message.data);
          });
        }
      }
    });
  }

  void _navigateToChat(Map<String, dynamic> data) {
    String senderId = data['senderId'] ?? '';
    String senderName = data['senderName'] ?? 'အသုံးပြုသူ';

    if (senderId.isNotEmpty) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            receiverId: senderId,
            receiverName: senderName,
          ),
        ),
      );
    }
  }

  void _checkInitialCall() async {
    if (kIsWeb) return; // Web တွင် မသုံးပါ
    try {
      var calls = await FlutterCallkitIncoming.activeCalls();

      if (calls is List && calls.isNotEmpty) {
        var call = calls.first;
        var extra = call['extra'];
        String callId = extra != null ? (extra['callId'] ?? '') : '';
        String callerName = call['nameCaller'] ?? 'အမည်မသိ';

        if (callId.isNotEmpty) {
          _listenToSpecificCall(callId, callerName);

          await Future.delayed(const Duration(milliseconds: 800));

          await FirebaseFirestore.instance
              .collection('calls')
              .doc(callId)
              .update({'status': 'accepted'});

          await FlutterCallkitIncoming.endAllCalls();

          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallScreen(
                callId: callId,
                currentUid: currentUid,
                isCaller: false,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print("Error checking initial call: $e");
    }
  }

  void _checkCallKitEvents() async {
    if (kIsWeb) return; // Web တွင် မသုံးပါ
    FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;

      final eventBody = event.body;
      String callId = '';

      if (eventBody != null) {
        if (eventBody['extra'] != null) {
          callId = eventBody['extra']['callId'] ?? '';
        }
      }

      String eventName = event.event.toString();

      if (eventName.contains('Accept') || eventName == 'actionCallAccept') {
        _callDocSub?.cancel();

        if (callId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(callId)
              .update({'status': 'accepted'});

          await FlutterCallkitIncoming.endAllCalls();
          await FlutterLocalNotificationsPlugin().cancelAll();

          await Future.delayed(const Duration(milliseconds: 300));

          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CallScreen(
                callId: callId,
                currentUid: currentUid,
                isCaller: false,
              ),
            ),
          );
        }
      } else if (eventName.contains('Decline') ||
          eventName == 'actionCallDeclined' ||
          eventName == 'actionCallTimeout') {
        _callDocSub?.cancel();

        if (callId.isNotEmpty) {
          await _callService.endCall(callId, currentUid: currentUid);
          await FlutterCallkitIncoming.endAllCalls();
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _rainbowController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _pages[_selectedIndex],
        bottomNavigationBar: SafeArea(
          bottom: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home_rounded, 'Home', isDark),
                    _buildNavItem(
                        1, Icons.card_giftcard_rounded, 'Reward', isDark),
                    _buildChatNavItem(2, isDark),
                    _buildNavItem(
                        3, Icons.notifications_rounded, 'Noti', isDark),
                    _buildNavItem(4, Icons.person_rounded, 'Profile', isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _rainbowController,
        builder: (context, child) {
          Color glowColor = Colors.transparent;
          if (isSelected) {
            final double value = _rainbowController.value;
            if (value < 0.2) {
              glowColor = Colors.redAccent;
            } else if (value < 0.4) {
              glowColor = Colors.orangeAccent;
            } else if (value < 0.6) {
              glowColor = Colors.yellowAccent;
            } else if (value < 0.8) {
              glowColor = Colors.greenAccent;
            } else {
              glowColor = Colors.purpleAccent;
            }
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 14 : 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? Colors.blue.withOpacity(0.25)
                      : Colors.blue.withOpacity(0.12))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: glowColor.withOpacity(0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: isSelected ? 26 : 22,
                  color: isSelected
                      ? Colors.blueAccent
                      : (isDark ? Colors.white : Colors.black87),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatNavItem(int index, bool isDark) {
    bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _rainbowController,
        builder: (context, child) {
          Color glowColor = Colors.transparent;
          if (isSelected) {
            final double value = _rainbowController.value;
            if (value < 0.2) {
              glowColor = Colors.redAccent;
            } else if (value < 0.4) {
              glowColor = Colors.orangeAccent;
            } else if (value < 0.6) {
              glowColor = Colors.yellowAccent;
            } else if (value < 0.8) {
              glowColor = Colors.greenAccent;
            } else {
              glowColor = Colors.purpleAccent;
            }
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 14 : 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                      ? Colors.blue.withOpacity(0.25)
                      : Colors.blue.withOpacity(0.12))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: glowColor.withOpacity(0.6),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('messages')
                      .where('isRead', isEqualTo: false)
                      .where('receiverId', isEqualTo: currentUid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int count =
                        snapshot.hasData ? snapshot.data!.docs.length : 0;

                    return badges.Badge(
                      showBadge: count > 0,
                      badgeContent: Text("$count",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                      child: Icon(
                        Icons.chat_rounded,
                        size: isSelected ? 26 : 22,
                        color: isSelected
                            ? Colors.blueAccent
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    );
                  },
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Chat',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
