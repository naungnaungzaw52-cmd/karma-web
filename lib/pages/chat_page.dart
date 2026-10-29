// ignore_for_file: avoid_print, use_build_context_synchronously, unused_local_variable

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:karma/main.dart';
import 'package:karma/pages/group_user_list_page.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:karma/pages/call_screen.dart';
import 'package:karma/services/notification_service.dart';
import 'package:karma/services/call_service.dart';
import 'package:karma/services/r2_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:karma/widgets/post_detail_screen.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:karma/pages/other_profile_page.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';

class NavigationHelper {
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final bool isGroup;
  final String? chatIdOverride;

  const ChatPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.isGroup = false,
    this.chatIdOverride,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  // ignore: unused_field
  final CallService _callService = CallService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _deleteGroupComplete(String chatId, String? groupImageUrl) async {
    bool confirmDelete = await showDialog(
          context: context,
          builder: (context) => ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return AlertDialog(
                title: Text(isMm ? 'Group ကို လုံးဝဖျက်ရန်' : 'Delete Group'),
                content: Text(
                  isMm
                      ? 'ဒီ Group ကို ဖျက်လိုက်ရင် မက်ဆေ့ခ်ျတွေ၊ ပုံတွေနဲ့ အချက်အလက်တွေ အားလုံး အပြီးတိုင် ပျက်သွားမှာ သေချာပါသလား?'
                      : 'Are you sure you want to completely delete this group? All messages, images, and data will be permanently lost.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(isMm ? 'မလုပ်ပါ' : 'Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      isMm ? 'ဖျက်မည်' : 'Delete',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    if (!confirmDelete) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (groupImageUrl != null && groupImageUrl.isNotEmpty) {
        await R2Service.deleteFile(groupImageUrl);
      }

      var messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      for (var doc in messagesSnapshot.docs) {
        var msgData = doc.data();
        String mediaUrl = msgData['mediaUrl'] ?? '';
        List<dynamic> mediaUrls = msgData['mediaUrls'] ?? [];

        if (mediaUrls.isNotEmpty) {
          for (var url in mediaUrls) {
            await R2Service.deleteFile(url.toString());
          }
        } else if (mediaUrl.isNotEmpty) {
          await R2Service.deleteFile(mediaUrl);
        }

        await doc.reference.delete();
      }

      await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();

      if (!mounted) return;
      Navigator.pop(context);
      bool isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'Group ကို အောင်မြင်စွာ ဖျက်ပြီးပါပြီ'
                : 'Group successfully deleted.',
          ),
        ),
      );
    } catch (e) {
      print("Delete Group Error: $e");
      if (!mounted) return;
      bool isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'Group ဖျက်၍ မအောင်မြင်ပါ: $e'
                : 'Failed to delete group: $e',
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _markMessagesAsRead() async {
    var querySnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(getChatId())
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('receiverId', isEqualTo: currentUid)
        .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  String getChatId() {
    if (widget.chatIdOverride != null && widget.chatIdOverride!.isNotEmpty) {
      return widget.chatIdOverride!;
    }
    if (widget.isGroup) {
      return widget.receiverId;
    }
    List ids = [currentUid, widget.receiverId];
    ids.sort();
    return ids.join("_");
  }

  Future _sendMessage({
    String? mediaUrl,
    List? mediaUrls,
    String messageType = 'text',
  }) async {
    String text = _messageController.text.trim();
    if (text.isEmpty &&
        mediaUrl == null &&
        (mediaUrls == null || mediaUrls.isEmpty)) return;

    String chatId = getChatId();
    String senderName =
        FirebaseAuth.instance.currentUser?.displayName ?? "အသုံးပြုသူ";

    if (messageType == 'text' &&
        (text.startsWith('http://') || text.startsWith('https://'))) {
      messageType = 'link';
    }

    List<String> finalMediaUrls = [];
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      finalMediaUrls = mediaUrls.map((e) => e.toString()).toList();
    } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
      finalMediaUrls.add(mediaUrl);
    }

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': currentUid,
      'receiverId': widget.isGroup ? '' : widget.receiverId,
      'text': text,
      'mediaUrl': finalMediaUrls.isNotEmpty ? finalMediaUrls[0] : '',
      'mediaUrls': finalMediaUrls,
      'type': messageType,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    bool isMm = isMyanmarNotifier.value;
    String lastMsgPreview = messageType == 'image'
        ? (finalMediaUrls.length > 1
            ? (isMm
                ? '📷 ပုံ ${finalMediaUrls.length} ပုံ ပို့ခဲ့သည်'
                : '📷 Sent ${finalMediaUrls.length} images')
            : (isMm ? '📷 ပုံတစ်ပုံ ပို့ခဲ့သည်' : '📷 Sent an image'))
        : messageType == 'video'
            ? (isMm ? '🎥 ဗီဒီယို တစ်ခု ပို့ခဲ့သည်' : '🎥 Sent a video')
            : messageType == 'file'
                ? (isMm ? '📁 ဖိုင်တွဲ တစ်ခု ပို့ခဲ့သည်' : '📁 Sent a file')
                : messageType == 'shared_post'
                    ? (isMm ? '🔄 မျှဝေထားသော ပို့စ်' : '🔄 Shared a post')
                    : text;

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': lastMsgPreview,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': widget.isGroup ? null : [currentUid, widget.receiverId],
      'isGroup': widget.isGroup,
    }, SetOptions(merge: true));

    if (!widget.isGroup) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverId)
          .get();

      if (userDoc.exists && userDoc['fcmToken'] != null) {
        NotificationService.sendNotification(
          userDoc['fcmToken'],
          lastMsgPreview,
          senderName,
          'message',
          senderId: currentUid,
        );
      }
    }
    _messageController.clear();
  }

  // 🌟 ၁။ ပုံများစွာ (Multi-Images) တင်ခြင်း
  Future _pickAndUploadMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await ImagePicker().pickMultiImage();
      if (pickedFiles.isEmpty) return;

      setState(() {
        _isLoading = true;
      });

      List<String> uploadedUrls = [];
      for (var pickedFile in pickedFiles) {
        // Web နှင့် Mobile နှစ်ခုလုံးအတွက် XFile ကို တိုက်ရိုက် ပေးပို့ခြင်း
        String? url = await R2Service.uploadFile(pickedFile, 'chat_media');
        if (url != null) {
          uploadedUrls.add(url);
        }
      }

      if (uploadedUrls.isNotEmpty) {
        await _sendMessage(mediaUrls: uploadedUrls, messageType: 'image');
      } else {
        bool isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm ? 'ပုံများတင်၍ မအောင်မြင်ပါ။' : 'Failed to upload images.',
            ),
          ),
        );
      }
    } catch (e) {
      print("Multi Image Upload Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🌟 ၂။ ဗီဒီယို တင်ခြင်း (Gallery မှ)
  Future _pickAndUploadVideo() async {
    final XFile? pickedFile =
        await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // XFile ကို တိုက်ရိုက် ပေးပို့ခြင်းဖြင့် Web မှာပါ Error မတက်တော့ပါ
      String? mediaUrl = await R2Service.uploadFile(pickedFile, 'chat_media');

      if (mediaUrl != null) {
        await _sendMessage(mediaUrl: mediaUrl, messageType: 'video');
      } else {
        bool isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm ? 'ဗီဒီယိုတင်၍ မအောင်မြင်ပါ။' : 'Failed to upload video.',
            ),
          ),
        );
      }
    } catch (e) {
      print("Video Upload Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🌟 ၃။ ကင်မရာဖြင့် ဓာတ်ပုံရိုက်၍ တင်ခြင်း
  Future _pickAndUploadCameraImage() async {
    try {
      final XFile? pickedFile =
          await ImagePicker().pickImage(source: ImageSource.camera);
      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
      });

      String? url = await R2Service.uploadFile(pickedFile, 'chat_media');

      if (url != null) {
        await _sendMessage(mediaUrl: url, messageType: 'image');
      } else {
        bool isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm ? 'ဓာတ်ပုံတင်၍ မအောင်မြင်ပါ။' : 'Failed to upload image.',
            ),
          ),
        );
      }
    } catch (e) {
      print("Camera Image Upload Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 🌟 ၄။ ကင်မရာဖြင့် ဗီဒီယိုရိုက်၍ တင်ခြင်း
  Future _pickAndUploadCameraVideo() async {
    try {
      final XFile? pickedFile =
          await ImagePicker().pickVideo(source: ImageSource.camera);
      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
      });

      String? mediaUrl = await R2Service.uploadFile(pickedFile, 'chat_media');

      if (mediaUrl != null) {
        await _sendMessage(mediaUrl: mediaUrl, messageType: 'video');
      } else {
        bool isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm ? 'ဗီဒီယိုတင်၍ မအောင်မြင်ပါ။' : 'Failed to upload video.',
            ),
          ),
        );
      }
    } catch (e) {
      print("Camera Video Upload Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

// 🌟 ဖိုင် (PDF, Word, etc.) ရွေးချယ်ပြီး R2 ထဲသို့ တင်မည့် Method
  Future _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
        });

        // Web သို့မဟုတ် Mobile အပေါ်မူတည်၍ File (သို့မဟုတ် XFile) ကို ပို့ပေးခြင်း
        File file = File(result.files.single.path!);
        String? mediaUrl = await R2Service.uploadFile(file, 'chat_files');

        if (mediaUrl != null) {
          _messageController.text = result.files.single.name;
          await _sendMessage(mediaUrl: mediaUrl, messageType: 'file');
        } else {
          bool isMm = isMyanmarNotifier.value;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isMm ? 'ဖိုင်တင်၍ မအောင်မြင်ပါ။' : 'Failed to upload file.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      print("File Pick Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openVideoWebView(String videoUrl) {
    NavigationHelper.push(
      context,
      _VideoWebViewScreen(videoUrl: videoUrl),
    );
  }

  void _showGroupManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => _GroupManagementDialog(
        chatId: getChatId(),
        isExistingGroup: widget.isGroup,
      ),
    );
  }

  void _showMediaSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: isMyanmarNotifier,
        builder: (context, isMm, child) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                isMm ? "ဖိုင်ပေးပို့ရန် ရွေးချယ်ပါ" : "Select File to Send",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: Text(isMm
                    ? "ကင်မရာဖြင့် ဓာတ်ပုံရိုက်မည်"
                    : "Take Photo with Camera"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadCameraImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.redAccent),
                title: Text(isMm
                    ? "ကင်မရာဖြင့် ဗီဒီယိုရိုက်မည်"
                    : "Record Video with Camera"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadCameraVideo();
                },
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: Text(isMm
                    ? "ဂယ်လီယာမှ ပုံများစွာ (Multi-Images) ရွေးမည်"
                    : "Select Multiple Images from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadMultipleImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.purple),
                title: Text(isMm
                    ? "ဂယ်လီယာမှ ဗီဒီယိုရွေးမည်"
                    : "Select Video from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadVideo();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.insert_drive_file, color: Colors.orange),
                title: Text(isMm
                    ? "ဖိုင် (PDF, Word, etc.) ပို့မည်"
                    : "Send File (PDF, Word, etc.)"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadFile();
                },
              ),
            ]),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(
      DocumentReference messageRef, Map<String, dynamic> msgData) {
    String mediaUrl = msgData['mediaUrl'] ?? '';
    List mediaUrls = msgData['mediaUrls'] ?? [];

    showDialog(
      context: context,
      builder: (context) => ValueListenableBuilder<bool>(
        valueListenable: isMyanmarNotifier,
        builder: (context, isMm, child) {
          return AlertDialog(
            title: Text(isMm ? 'မက်ဆေ့ခ်ျဖျက်ရန်' : 'Delete Message'),
            content: Text(
              isMm
                  ? 'ဒီမက်ဆေ့ခ်ျကို ဖျက်မှာ သေချာပါသလား?'
                  : 'Are you sure you want to delete this message?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isMm ? 'မလုပ်ပါ' : 'Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    // ၁။ R2 ထဲက Media ဖိုင်များကို ဖျက်ခြင်း
                    if (mediaUrls.isNotEmpty) {
                      for (var url in mediaUrls) {
                        await R2Service.deleteFile(url.toString());
                      }
                    } else if (mediaUrl.isNotEmpty) {
                      await R2Service.deleteFile(mediaUrl);
                    }

                    // ၂။ Firestore ထဲက message ကို ဖျက်ခြင်း
                    await messageRef.delete();

                    // 🛠️ ၃။ မက်ဆေ့ခ်ျဖျက်ပြီးပါက ကျန်ရှိနေသေးသော နောက်ဆုံး မက်ဆေ့ခ်ျကို ရှာပြီး chats doc ကို update လုပ်ခြင်း
                    String chatId = getChatId();
                    var remainingMessages = await FirebaseFirestore.instance
                        .collection('chats')
                        .doc(chatId)
                        .collection('messages')
                        .orderBy('createdAt', descending: true)
                        .limit(1)
                        .get();

                    if (remainingMessages.docs.isNotEmpty) {
                      var lastMsgData = remainingMessages.docs.first.data();
                      String lastMsgType = lastMsgData['type'] ?? 'text';
                      String lastMsgText = lastMsgData['text'] ?? '';
                      List<dynamic> lastMediaUrls =
                          lastMsgData['mediaUrls'] ?? [];

                      String newLastMessage = lastMsgType == 'image'
                          ? (lastMediaUrls.length > 1
                              ? (isMm
                                  ? '📷 ပုံ ${lastMediaUrls.length} ပုံ ပို့ခဲ့သည်'
                                  : '📷 Sent ${lastMediaUrls.length} images')
                              : (isMm
                                  ? '📷 ပုံတစ်ပုံ ပို့ခဲ့သည်'
                                  : '📷 Sent an image'))
                          : lastMsgType == 'video'
                              ? (isMm
                                  ? '🎥 ဗီဒီယို တစ်ခု ပို့ခဲ့သည်'
                                  : '🎥 Sent a video')
                              : lastMsgType == 'file'
                                  ? (isMm
                                      ? '📁 ဖိုင်တွဲ တစ်ခု ပို့ခဲ့သည်'
                                      : '📁 Sent a file')
                                  : lastMsgType == 'shared_post'
                                      ? (isMm
                                          ? '🔄 မျှဝေထားသော ပို့စ်'
                                          : '🔄 Shared a post')
                                      : lastMsgText;

                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .update({
                        'lastMessage': newLastMessage,
                        'lastTimestamp': lastMsgData['createdAt'] ??
                            FieldValue.serverTimestamp(),
                      });
                    } else {
                      // မက်ဆေ့ခ်ျ လုံးဝမကျန်တော့ပါက
                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .update({
                        'lastMessage':
                            isMm ? 'စာများ မရှိတော့ပါ' : 'No messages',
                        'lastTimestamp': FieldValue.serverTimestamp(),
                      });
                    }

                    if (!mounted) return;
                    bool isMmSnackBar = isMyanmarNotifier.value;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isMmSnackBar
                              ? 'မက်ဆေ့ခ်ျကို ဖျက်ပြီးပါပြီ'
                              : 'Message successfully deleted.',
                        ),
                      ),
                    );
                  } catch (e) {
                    print("Error deleting message: $e");
                  }
                },
                child: Text(
                  isMm ? 'ဖျက်မည်' : 'Delete',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDarkMode = themeProvider.currentTheme != 'Default';

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          // 🛠️ Overflow မဖြစ်အောင် Expanded / Flexible ဖြင့် အသေအချာ ချိန်ညှိပေးထားသည်
          title: widget.isGroup
              ? StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(getChatId())
                      .snapshots(),
                  builder: (context, snapshot) {
                    String? groupImageUrl;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      var chatData =
                          snapshot.data!.data() as Map<String, dynamic>;
                      groupImageUrl = chatData['groupImage'];
                    }

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.blueGrey,
                          backgroundImage:
                              groupImageUrl != null && groupImageUrl.isNotEmpty
                                  ? NetworkImage(groupImageUrl)
                                  : null,
                          child: groupImageUrl == null || groupImageUrl.isEmpty
                              ? const Icon(Icons.group,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.receiverName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.getTextColor(),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                )
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.receiverId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    String statusText = "Offline";
                    bool isOnline = false;
                    String? profileImageUrl;
                    String? userRole;

                    if (snapshot.hasData && snapshot.data!.exists) {
                      var userData =
                          snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      isOnline = userData['isOnline'] ?? false;
                      Timestamp? lastActive = userData['lastActive'];
                      profileImageUrl = userData['profileImageUrl'];
                      userRole = userData['role'];

                      bool isMm = isMyanmarNotifier.value;

                      if (isOnline) {
                        statusText = isMm ? "Online ရှိနေသည်" : "Online";
                      } else if (lastActive != null) {
                        DateTime dateTime = lastActive.toDate();
                        DateTime now = DateTime.now();
                        Duration diff = now.difference(dateTime);

                        if (diff.inMinutes < 1) {
                          statusText = isMm
                              ? "ယခုလေးတင်က Active ဖြစ်ခဲ့သည်"
                              : "Just now";
                        } else if (diff.inHours < 1) {
                          statusText = isMm
                              ? "လွန်ခဲ့သော ${diff.inMinutes} မိနစ်က"
                              : "${diff.inMinutes}m ago";
                        } else if (diff.inDays < 1) {
                          statusText = isMm
                              ? "လွန်ခဲ့သော ${diff.inHours} နာရီက"
                              : "${diff.inHours}h ago";
                        } else {
                          statusText = isMm
                              ? "${dateTime.month}/${dateTime.day} တွင် Active ဖြစ်ခဲ့သည်"
                              : "Active on ${dateTime.month}/${dateTime.day}";
                        }
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        NavigationHelper.push(
                          context,
                          OtherProfilePage(
                            userId: widget.receiverId,
                            userName: '',
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey.shade300,
                                backgroundImage: profileImageUrl != null &&
                                        profileImageUrl.isNotEmpty
                                    ? NetworkImage(profileImageUrl)
                                    : const NetworkImage(
                                        "https://cdn-icons-png.flaticon.com/512/3135/3135768.png"),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        isOnline ? Colors.green : Colors.grey,
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GoldenNameWidget(
                                  name: widget.receiverName,
                                  role: userRole,
                                  fontSize: 15,
                                  isWhiteBackground: !isDarkMode,
                                ),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOnline
                                        ? Colors.green
                                        : Colors.grey.shade400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          actions: [
            if (widget.isGroup)
              ValueListenableBuilder<bool>(
                valueListenable: isMyanmarNotifier,
                builder: (context, isMm, child) {
                  return IconButton(
                    icon: const Icon(Icons.delete_forever,
                        color: Colors.redAccent),
                    tooltip: isMm ? "Group ကို ဖျက်ရန်" : "Delete Group",
                    onPressed: () async {
                      var doc = await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(getChatId())
                          .get();
                      String? gImage;
                      if (doc.exists && doc.data() != null) {
                        final data = doc.data() as Map<String, dynamic>;
                        gImage = data['groupImage'] as String?;
                      }
                      _deleteGroupComplete(getChatId(), gImage);
                    },
                  );
                },
              ),
            if (widget.isGroup)
              ValueListenableBuilder<bool>(
                valueListenable: isMyanmarNotifier,
                builder: (context, isMm, child) {
                  return IconButton(
                    icon: const Icon(Icons.group, color: Colors.blueAccent),
                    tooltip: isMm
                        ? "Group အဖွဲ့ဝင်များ ကြည့်ရန်"
                        : "View Group Members",
                    onPressed: () async {
                      var doc = await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(getChatId())
                          .get();

                      bool isAdmin = false;
                      if (doc.exists && doc.data() != null) {
                        List<dynamic> admins = doc['adminIds'] ?? [];
                        isAdmin = admins.contains(currentUid);
                      }

                      NavigationHelper.push(
                        context,
                        GroupUserListPage(
                          chatId: getChatId(),
                          isAdmin: isAdmin,
                        ),
                      );
                    },
                  );
                },
              ),
            ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return IconButton(
                  icon: Icon(
                      widget.isGroup ? Icons.person_add : Icons.group_add,
                      color: Colors.blueAccent),
                  tooltip: widget.isGroup
                      ? (isMm ? "အဖွဲ့ဝင်များ ထည့်ရန်" : "Add Members")
                      : (isMm ? "Group Chat ဖန်တီးရန်" : "Create Group Chat"),
                  onPressed: _showGroupManagementDialog,
                );
              },
            ),
            if (!widget.isGroup) ...[
              IconButton(
                icon: const Icon(Icons.call, color: Colors.blueAccent),
                onPressed: () async {
                  String currentUserName =
                      FirebaseAuth.instance.currentUser?.displayName ??
                          "အသုံးပြုသူ";
                  String currentUserAvatar = FirebaseAuth
                          .instance.currentUser?.photoURL ??
                      "https://cdn-icons-png.flaticon.com/512/3135/3135768.png";

                  String callId = await _callService.startCall(
                    callerId: currentUid,
                    callerName: currentUserName,
                    receiverId: widget.receiverId,
                    callerAvatar: currentUserAvatar,
                  );

                  if (callId.isNotEmpty && mounted) {
                    NavigationHelper.push(
                      context,
                      CallScreen(
                          callId: callId,
                          currentUid: currentUid,
                          isCaller: true),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.videocam, color: Colors.blueAccent),
                onPressed: () async {
                  String currentUserName =
                      FirebaseAuth.instance.currentUser?.displayName ??
                          "အသုံးပြုသူ";
                  String currentUserAvatar = FirebaseAuth
                          .instance.currentUser?.photoURL ??
                      "https://cdn-icons-png.flaticon.com/512/3135/3135768.png";

                  String callId = await _callService.startCall(
                    callerId: currentUid,
                    callerName: currentUserName,
                    receiverId: widget.receiverId,
                    callerAvatar: currentUserAvatar,
                  );

                  if (callId.isNotEmpty && mounted) {
                    NavigationHelper.push(
                      context,
                      CallScreen(
                          callId: callId,
                          currentUid: currentUid,
                          isCaller: true),
                    );
                  }
                },
              ),
            ],
            const SizedBox(width: 4),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(getChatId())
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead();
                });

                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var msg = snapshot.data!.docs[index];
                    var msgData = msg.data() as Map<String, dynamic>;
                    bool isMe = msgData['senderId'] == currentUid;
                    String messageText = msgData['text'] ?? '';
                    String mediaUrl = msgData['mediaUrl'] ?? '';
                    List<dynamic> rawMediaUrls = msgData['mediaUrls'] ?? [];
                    List<String> mediaUrls =
                        rawMediaUrls.map((e) => e.toString()).toList();
                    if (mediaUrls.isEmpty && mediaUrl.isNotEmpty) {
                      mediaUrls.add(mediaUrl);
                    }

                    String messageType = msgData['type'] ?? 'text';
                    bool isRead = msgData['isRead'] ?? false;

                    return GestureDetector(
                      onLongPress: () {
                        if (isMe) {
                          _showDeleteDialog(msg.reference, msgData);
                        }
                      },
                      child: Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75),
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Colors.blueAccent
                                : (isDarkMode
                                    ? Colors.grey.shade800
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (mediaUrls.isNotEmpty &&
                                  messageType == 'image') ...[
                                _buildChatGridMedia(context, mediaUrls),
                                if (messageText.isNotEmpty)
                                  const SizedBox(height: 8),
                              ],
                              if (mediaUrl.isNotEmpty &&
                                  messageType == 'video') ...[
                                GestureDetector(
                                  onTap: () => _openVideoWebView(mediaUrl),
                                  child: Container(
                                    height: 150,
                                    width: 200,
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.play_circle_fill,
                                              size: 50, color: Colors.white),
                                          const SizedBox(height: 4),
                                          ValueListenableBuilder<bool>(
                                            valueListenable: isMyanmarNotifier,
                                            builder: (context, isMm, child) {
                                              return Text(
                                                isMm
                                                    ? "ဗီဒီယိုကြည့်ရန် & Download"
                                                    : "Watch & Download Video",
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (messageText.isNotEmpty)
                                  const SizedBox(height: 8),
                              ],
                              if (mediaUrl.isNotEmpty &&
                                  messageType == 'file') ...[
                                Row(
                                  children: [
                                    Icon(Icons.insert_drive_file,
                                        color: isMe
                                            ? Colors.white
                                            : Colors.blueAccent,
                                        size: 30),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ValueListenableBuilder<bool>(
                                        valueListenable: isMyanmarNotifier,
                                        builder: (context, isMm, child) {
                                          return Text(
                                            messageText.isNotEmpty
                                                ? messageText
                                                : (isMm ? "ဖိုင်တွဲ" : "File"),
                                            style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : (isDarkMode
                                                        ? Colors.white
                                                        : Colors.black87),
                                                fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (messageType == 'shared_post') ...[
                                GestureDetector(
                                  onTap: () {
                                    String? postId = msgData['postId'];
                                    if (postId != null && postId.isNotEmpty) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PostDetailScreen(postId: postId),
                                        ),
                                      );
                                    } else {
                                      bool isMm = isMyanmarNotifier.value;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            isMm
                                                ? 'ပို့စ် ID ကို ရှာမတွေ့ပါ။'
                                                : 'Post ID not found.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? Colors.blue.shade50
                                          : Colors.grey.shade100,
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ValueListenableBuilder<bool>(
                                          valueListenable: isMyanmarNotifier,
                                          builder: (context, isMm, child) {
                                            return Text(
                                              isMm
                                                  ? "🔄 မျှဝေထားသော ပို့စ်"
                                                  : "🔄 Shared Post",
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.bold),
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          messageText.isNotEmpty
                                              ? messageText
                                              : (msgData['message'] ?? ''),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isMe
                                                ? Colors.black87
                                                : (isDarkMode
                                                    ? Colors.white
                                                    : Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              if (messageText.isNotEmpty &&
                                  messageType != 'file' &&
                                  messageType != 'image' &&
                                  messageType != 'shared_post')
                                InkWell(
                                  onTap: messageType == 'link'
                                      ? () async {
                                          final Uri url =
                                              Uri.parse(messageText);
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url,
                                                mode: LaunchMode
                                                    .externalApplication);
                                          } else {
                                            bool isMm = isMyanmarNotifier.value;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  isMm
                                                      ? 'ဤလင့်ခ်ကို ဖွင့်၍မရပါ။'
                                                      : 'Could not open this link.',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                  child: Text(
                                    messageText,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : (isDarkMode
                                              ? Colors.white
                                              : Colors.black87),
                                      fontSize: 15,
                                      decoration: messageType == 'link'
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              if (isMe)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isRead ? "Seen" : "Sent",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      isRead ? Icons.done_all : Icons.done,
                                      size: 14,
                                      color: isRead
                                          ? Colors.lightGreenAccent
                                          : Colors.white70,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          // 🌟 စာရိုက်သည့် Container ကို SafeArea ဖြင့် ခြုံပေးခြင်း
          SafeArea(
            bottom: true,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              margin: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0), // ပိုလှစေရန် margin အနည်းငယ်ထည့်နိုင်သည်
              decoration: BoxDecoration(
                // 🌟 Glassmorphism (အကြည်ရောင်) ပုံစံအတွက် နောက်ခံအရောင်နှင့် ပွင့်လင်းမြင်သာမှု
                color: isDarkMode
                    ? Colors.black.withOpacity(0.3)
                    : Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(20),
                // မှန်သားပြင်ကဲ့သို့ ပါးလွှာသော ဘောင် (Border) ထည့်ခြင်း
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.15)
                      : Colors.white.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.blueAccent),
                  onPressed: _showMediaSourceActionSheet,
                ),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return TextField(
                        controller: _messageController,
                        style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: isMm
                              ? "စာ သို့မဟုတ် Link ရိုက်ပါ..."
                              : "Type a message or link...",
                          hintStyle: TextStyle(
                              color: isDarkMode ? Colors.grey : Colors.black45),
                          border: InputBorder.none,
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: () => _sendMessage(messageType: 'text'),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildChatGridMedia(BuildContext context, List mediaUrls) {
    if (mediaUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: () => _showFullScreenGallery(context, mediaUrls, 0),
          child: Image.network(
            mediaUrls[0],
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 180,
        width: 220,
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: mediaUrls.length > 4 ? 4 : mediaUrls.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _showFullScreenGallery(context, mediaUrls, index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    mediaUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        ValueListenableBuilder<bool>(
                      valueListenable: isMyanmarNotifier,
                      builder: (context, isMm, child) {
                        return Center(
                          child: Text(
                            isMm ? "ပုံအမှား" : "Image Error",
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      },
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
                            fontSize: 18,
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

  void _showFullScreenGallery(
      BuildContext context, List mediaUrls, int initialIndex) {
    NavigationHelper.push(
      context,
      _FullScreenGalleryScreen(
        mediaUrls: mediaUrls,
        initialIndex: initialIndex,
      ),
    );
  }
}

// -------------------------------------------------------------
// Group Management Dialog
// -------------------------------------------------------------
class _GroupManagementDialog extends StatefulWidget {
  final String chatId;
  final bool isExistingGroup;

  const _GroupManagementDialog({
    required this.chatId,
    required this.isExistingGroup,
  });

  @override
  State<_GroupManagementDialog> createState() => _GroupManagementDialogState();
}

class _GroupManagementDialogState extends State<_GroupManagementDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final List _selectedUserIds = [];
  bool _isLoading = false;
  File? _groupImageFile;
  String? _existingGroupImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.isExistingGroup) {
      _loadExistingGroupData();
    }
  }

  void _loadExistingGroupData() async {
    var doc = await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .get();
    if (doc.exists && doc.data() != null) {
      var data = doc.data() as Map<String, dynamic>;
      setState(() {
        _existingGroupImageUrl = data['groupImage'];
      });
    }
  }

  Future _pickGroupImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _groupImageFile = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future _createOrUpdateGroup() async {
    if (!widget.isExistingGroup && _groupNameController.text.trim().isEmpty) {
      bool isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'ကျေးဇူးပြု၍ Group အမည် ထည့်ပါ။'
                : 'Please enter a group name.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;

      String? uploadedImageUrl = _existingGroupImageUrl;
      if (_groupImageFile != null) {
        uploadedImageUrl =
            await R2Service.uploadFile(_groupImageFile!, 'group_images');
      }

      if (!widget.isExistingGroup) {
        String newGroupId =
            FirebaseFirestore.instance.collection('chats').doc().id;
        List<String> members = [currentUid, ..._selectedUserIds];

        bool isMm = isMyanmarNotifier.value;
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(newGroupId)
            .set({
          'isGroup': true,
          'groupName': _groupNameController.text.trim(),
          'groupImage': uploadedImageUrl ?? '',
          'adminIds': [currentUid],
          'members': members,
          'lastMessage': isMm ? 'Group ဖန်တီးခဲ့သည်' : 'Created a group',
          'lastTimestamp': FieldValue.serverTimestamp(),
          'chatTheme': 'default',
        });

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? 'Group Chat အောင်မြင်စွာ ဖန်တီးပြီးပါပြီ'
                  : 'Group chat successfully created.',
            ),
          ),
        );

        NavigationHelper.push(
          context,
          ChatPage(
            receiverId: newGroupId,
            receiverName: _groupNameController.text.trim(),
            isGroup: true,
            chatIdOverride: newGroupId,
          ),
        );
      } else {
        var docRef =
            FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
        var doc = await docRef.get();

        Map<String, dynamic> updateData = {
          'groupImage': uploadedImageUrl ?? '',
        };

        List<String> newlyAddedMembers = [];

        if (_selectedUserIds.isNotEmpty) {
          if (doc.exists) {
            List<dynamic> existingMembers = doc['members'] ?? [];
            for (var id in _selectedUserIds) {
              if (!existingMembers.contains(id)) {
                existingMembers.add(id);
                newlyAddedMembers.add(id);
              }
            }
            updateData['members'] = existingMembers;
          }
        }

        await docRef.update(updateData);

        for (String newMemberId in newlyAddedMembers) {
          var userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(newMemberId)
              .get();

          if (userDoc.exists && userDoc.data() != null) {
            var userData = userDoc.data() as Map<String, dynamic>;
            if (userData.containsKey('fcmToken') &&
                userData['fcmToken'] != null) {
              bool isMm = isMyanmarNotifier.value;
              NotificationService.sendNotification(
                userData['fcmToken'],
                isMm
                    ? 'သင့်ကို Group အသစ်တစ်ခုထဲသို့ ထည့်သွင်းလိုက်ပါပြီ'
                    : 'You have been added to a new group',
                isMm ? 'Group အကြောင်းကြားချက်' : 'Group Notification',
                'group_invite',
                senderId: currentUid,
              );
            }
          }
        }

        Navigator.pop(context);
        bool isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? 'Group အချက်အလက်များကို အောင်မြင်စွာ ပြင်ဆင်ပြီးပါပြီ'
                  : 'Group information successfully updated.',
            ),
          ),
        );
      }
    } catch (e) {
      print("Group Management Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return ValueListenableBuilder<bool>(
      valueListenable: isMyanmarNotifier,
      builder: (context, isMm, child) {
        return AlertDialog(
          title: Text(widget.isExistingGroup
              ? (isMm
                  ? 'Group အချက်အလက်ပြင်ရန် / အဖွဲ့ဝင်ထည့်ရန်'
                  : 'Edit Group Info / Add Members')
              : (isMm ? 'Group Chat အသစ်ဖန်တီးရန်' : 'Create New Group Chat')),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _pickGroupImage,
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.blueGrey,
                      backgroundImage: _groupImageFile != null
                          ? FileImage(_groupImageFile!)
                          : (_existingGroupImageUrl != null &&
                                  _existingGroupImageUrl!.isNotEmpty
                              ? NetworkImage(_existingGroupImageUrl!)
                                  as ImageProvider
                              : null),
                      child: (_groupImageFile == null &&
                              (_existingGroupImageUrl == null ||
                                  _existingGroupImageUrl!.isEmpty))
                          ? const Icon(Icons.add_a_photo,
                              size: 30, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isMm
                        ? "Group ပုံပြောင်းရန် နှိပ်ပါ"
                        : "Tap to change group photo",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  if (!widget.isExistingGroup) ...[
                    TextField(
                      controller: _groupNameController,
                      decoration: InputDecoration(
                        labelText: isMm ? 'Group အမည်' : 'Group Name',
                        hintText: isMm
                            ? 'ဥပမာ - Flutter Developers'
                            : 'e.g. Flutter Developers',
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                  Text(
                    isMm ? 'အဖွဲ့ဝင်များ ရွေးချယ်ရန်:' : 'Select Members:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        var users = snapshot.data!.docs
                            .where((doc) => doc.id != currentUid)
                            .toList();

                        return ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            var userDoc = users[index];
                            var userData =
                                userDoc.data() as Map<String, dynamic>;
                            String userId = userDoc.id;
                            String userName = userData['name'] ??
                                userData['displayName'] ??
                                (isMm ? 'အမည်မရှိ' : 'No Name');
                            String? userAvatar = userData['profileImageUrl'];

                            bool isSelected = _selectedUserIds.contains(userId);

                            return CheckboxListTile(
                              secondary: CircleAvatar(
                                backgroundImage: userAvatar != null &&
                                        userAvatar.isNotEmpty
                                    ? NetworkImage(userAvatar)
                                    : const NetworkImage(
                                        "https://cdn-icons-png.flaticon.com/512/3135/3135768.png"),
                              ),
                              title: Text(userName),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedUserIds.add(userId);
                                  } else {
                                    _selectedUserIds.remove(userId);
                                  }
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isMm ? 'ပယ်ဖျက်မည်' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _createOrUpdateGroup,
              child: Text(widget.isExistingGroup
                  ? (isMm ? 'သိမ်းမည်' : 'Save')
                  : (isMm ? 'ဖန်တီးမည်' : 'Create')),
            ),
          ],
        );
      },
    );
  }
}

// -------------------------------------------------------------
// Full-Screen Gallery Screen
// -------------------------------------------------------------
class _FullScreenGalleryScreen extends StatefulWidget {
  final List mediaUrls;
  final int initialIndex;

  const _FullScreenGalleryScreen({
    required this.mediaUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGalleryScreen> createState() =>
      _FullScreenGalleryScreenState();
}

class _FullScreenGalleryScreenState extends State<_FullScreenGalleryScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future _downloadCurrentImage() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      String imageUrl = widget.mediaUrls[_currentIndex];
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        String fileName = "image_${DateTime.now().millisecondsSinceEpoch}.jpg";
        File file = File('${directory?.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ပုံကို Download ဆွဲပြီးပါပြီ: ${file.path}')),
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ပုံ Download လုပ်၍ မအောင်မြင်ပါ: $e')),
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
        title: Text(
          "${_currentIndex + 1} / ${widget.mediaUrls.length}",
          style: const TextStyle(color: Colors.white, fontSize: 16),
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
                      onPressed: _downloadCurrentImage,
                      tooltip:
                          isMm ? "ပုံကို Download လုပ်ရန်" : "Download Image",
                    );
                  },
                ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                widget.mediaUrls[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    ValueListenableBuilder<bool>(
                  valueListenable: isMyanmarNotifier,
                  builder: (context, isMm, child) {
                    return Center(
                      child: Text(
                        isMm ? "ပုံကို ဖတ်၍မရပါ။" : "Failed to load image.",
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------
// Video WebView Screen
// -------------------------------------------------------------
class _VideoWebViewScreen extends StatefulWidget {
  final String videoUrl;
  const _VideoWebViewScreen({required this.videoUrl});

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

  Future _downloadVideo() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final response = await http.get(Uri.parse(widget.videoUrl));
      if (response.statusCode == 200) {
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        String fileName = "video_${DateTime.now().millisecondsSinceEpoch}.mp4";
        File file = File('${directory?.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (!mounted) return;
        bool isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? 'ဗီဒီယို Download ဆွဲပြီးပါပြီ: ${file.path}'
                  : 'Video downloaded successfully: ${file.path}',
            ),
          ),
        );
      } else {
        throw Exception('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      bool isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm ? 'Download လုပ်၍ မအောင်မြင်ပါ: $e' : 'Failed to download: $e',
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
    return ValueListenableBuilder<bool>(
      valueListenable: isMyanmarNotifier,
      builder: (context, isMm, child) {
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(isMm ? "ဗီဒီယို ကြည့်ရန်" : "Watch Video"),
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
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
                  : IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: _downloadVideo,
                      tooltip:
                          isMm ? "ဗီဒီယို Download လုပ်ရန်" : "Download Video",
                    ),
            ],
          ),
          body: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
            ],
          ),
        );
      },
    );
  }
}
