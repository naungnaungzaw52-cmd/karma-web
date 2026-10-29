// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:karma/main.dart';
import 'package:karma/pages/other_profile_page.dart';
import 'package:karma/services/notification_service.dart';
import 'package:karma/services/r2_service.dart';
import 'package:video_compress/video_compress.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:karma/pages/story_editor_page.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:provider/provider.dart';

class StoryViewWidget extends StatefulWidget {
  const StoryViewWidget({super.key});

  @override
  State<StoryViewWidget> createState() => _StoryViewWidgetState();
}

class _StoryViewWidgetState extends State<StoryViewWidget> {
  @override
  void initState() {
    super.initState();
    _deleteExpiredStories();
  }

  Future<void> _deleteExpiredStories() async {
    try {
      DateTime twentyFourHoursAgo =
          DateTime.now().subtract(const Duration(hours: 24));

      var expiredQuery = await FirebaseFirestore.instance
          .collection('stories')
          .where('createdAt',
              isLessThan: Timestamp.fromDate(twentyFourHoursAgo))
          .get();

      for (var doc in expiredQuery.docs) {
        var data = doc.data();
        String? mediaUrl = data['mediaUrl'];

        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          try {
            await R2Service.deleteFile(mediaUrl);
          } catch (e) {
            print("R2 File Delete Error: $e");
          }
        }

        await FirebaseFirestore.instance
            .collection('stories')
            .doc(doc.id)
            .delete();
      }
    } catch (e) {
      print("Expired Stories Cleanup Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return SizedBox(
      height: 65,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            List<dynamic> following = userData?['following'] ?? [];
            List<dynamic> followers = userData?['followers'] ?? [];
            String myProfileImage = userData?['profileImageUrl'] ?? '';

            List<String> allowedUserIds = [
              ...following,
              ...followers,
              currentUid
            ];

            DateTime twentyFourHoursAgo =
                DateTime.now().subtract(const Duration(hours: 24));

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stories')
                  .where('createdAt',
                      isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo))
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, storySnapshot) {
                if (!storySnapshot.hasData) {
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      AddStoryButton(
                        myProfileImage: myProfileImage,
                        hasMyStory: false,
                      )
                    ],
                  );
                }

                final stories = storySnapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return allowedUserIds.contains(data['uid']);
                }).toList();

                Map<String, List<QueryDocumentSnapshot>> groupedStories = {};
                for (var story in stories) {
                  var data = story.data() as Map<String, dynamic>;
                  String uid = data['uid'];
                  if (!groupedStories.containsKey(uid)) {
                    groupedStories[uid] = [];
                  }
                  groupedStories[uid]!.add(story);
                }

                // 🌟 ကိုယ့်အိုင်ဒီကို userIdsWithStories ထဲကနေ ဖယ်ထုတ်ထားမယ် (အခြားသူတွေအတွက် သီးသန့်သုံးဖို့)
                List<String> userIdsWithStories = groupedStories.keys
                    .where((uid) => uid != currentUid)
                    .toList();

                // 🌟 ကိုယ်ကိုယ်တိုင် Story တင်ထားရဲ့လား စစ်ဆေးခြင်း
                bool hasMyStory = groupedStories.containsKey(currentUid) &&
                    groupedStories[currentUid]!.isNotEmpty;

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: userIdsWithStories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return AddStoryButton(
                        myProfileImage: myProfileImage,
                        hasMyStory: hasMyStory,
                        onStoryTap: () {
                          _showStoryViewer(
                            context,
                            groupedStories,
                            [currentUid, ...userIdsWithStories],
                            currentUid,
                            currentUid,
                          );
                        },
                      );
                    }

                    // ကျန်တဲ့ အခြား user များအတွက်
                    String userId = userIdsWithStories[index - 1];
                    var userStories = groupedStories[userId]!;
                    var firstStoryData =
                        userStories.first.data() as Map<String, dynamic>;

                    return StoryAvatarItem(
                      userName: firstStoryData['userName'] ?? "အသုံးပြုသူ",
                      userImage: firstStoryData['userImage'] ?? "",
                      onTap: () {
                        List<String> allActiveUserIds = hasMyStory
                            ? [currentUid, ...userIdsWithStories]
                            : userIdsWithStories;
                        _showStoryViewer(context, groupedStories,
                            allActiveUserIds, userId, currentUid);
                      },
                    );
                  },
                );
              }, // 👈 ဒီ StreamBuilder ရဲ့ builder အတွက် ကွင်းပိတ်
            );
          }, // 👈 အပေါ်ဆုံး StreamBuilder ရဲ့ builder အတွက် ကွင်းပိတ်
        ),
      ),
    );
  }

  void _showStoryViewer(
    BuildContext context,
    Map<String, List<QueryDocumentSnapshot>> groupedStories,
    List<String> userIdsWithStories,
    String initialUserId,
    String currentUid,
  ) {
    final PageController userPageController = PageController(
      initialPage: userIdsWithStories.indexOf(initialUserId),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: PageView.builder(
            controller: userPageController,
            physics: const ClampingScrollPhysics(),
            itemCount: userIdsWithStories.length,
            itemBuilder: (context, userIndex) {
              String userId = userIdsWithStories[userIndex];
              List<QueryDocumentSnapshot> stories = groupedStories[userId]!;

              return SingleUserStoryScreen(
                stories: stories,
                currentUid: currentUid,
                onFinishedAllStories: () {
                  if (userIndex < userIdsWithStories.length - 1) {
                    userPageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
                onBackPressed: () {
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// 📱 User တစ်ဦးချင်းစီအတွက် Timer / Auto Play စနစ်ပါဝင်သော Screen
class SingleUserStoryScreen extends StatefulWidget {
  final List<QueryDocumentSnapshot> stories;
  final String currentUid;
  final VoidCallback onFinishedAllStories;
  final VoidCallback onBackPressed;

  const SingleUserStoryScreen({
    super.key,
    required this.stories,
    required this.currentUid,
    required this.onFinishedAllStories,
    required this.onBackPressed,
  });

  @override
  State<SingleUserStoryScreen> createState() => _SingleUserStoryScreenState();
}

class _SingleUserStoryScreenState extends State<SingleUserStoryScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _storyPageController;
  int _currentStoryIndex = 0;
  AnimationController? _animController;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _storyPageController = PageController();
    _startStoryTimer();
  }

  void _startStoryTimer() {
    _animController?.dispose();

    // Safe check index boundaries
    if (_currentStoryIndex >= widget.stories.length) return;

    var storyDoc = widget.stories[_currentStoryIndex];
    var story = storyDoc.data() as Map<String, dynamic>;
    String mediaUrl = story['mediaUrl'] ?? '';
    bool isVideo = _isVideoFile(mediaUrl);

    Duration duration =
        isVideo ? const Duration(seconds: 30) : const Duration(seconds: 5);

    _animController = AnimationController(vsync: this, duration: duration)
      ..forward().whenComplete(() {
        if (!_isPaused) {
          _goToNextStory();
        }
      });

    if (mounted) setState(() {});
  }

  bool _isVideoFile(String url) {
    String lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi') ||
        lower.contains('.webm');
  }

  void _goToNextStory() {
    if (_currentStoryIndex < widget.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _storyPageController.animateToPage(
        _currentStoryIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStoryTimer();
    } else {
      widget.onFinishedAllStories();
    }
  }

  void _goToPreviousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
      _storyPageController.animateToPage(
        _currentStoryIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStoryTimer();
    }
  }

  Future<void> _toggleStoryLike(DocumentSnapshot storyDoc) async {
    var data = storyDoc.data() as Map<String, dynamic>;
    List<dynamic> currentLikes = List.from(data['likes'] ?? []);
    String storyOwnerId = data['uid'] ?? '';
    String currentUserName =
        FirebaseAuth.instance.currentUser?.displayName ?? "အသုံးပြုသူ";

    bool isCurrentlyLiked = currentLikes.contains(widget.currentUid);

    setState(() {
      _isPaused = true;
      _animController?.stop();
    });

    try {
      if (isCurrentlyLiked) {
        // 🌟 1. အရင်က Like ထားပြီးသားဆိုရင် ဖြုတ်ရုံပဲဖြုတ်မယ် (Noti ဘာမှ မလုပ်ဘူး)
        await FirebaseFirestore.instance
            .collection('stories')
            .doc(storyDoc.id)
            .update({
          'likes': FieldValue.arrayRemove([widget.currentUid])
        });
      } else {
        // 🌟 2. Like ပြန်ပေးတဲ့အခါ Noti ခဏခဏ မတက်အောင် စစ်ဆေးမယ်
        // ဒီ Story မှာ အရင်က ကိုယ် Noti ပို့ဖူးလား ဆိုတာ Notifications Collection ထဲမှာ သွားစစ်မယ်
        final isMm = isMyanmarNotifier.value;
        final likeMessage = isMm
            ? "$currentUserName က သင့် Story ကို Like ပေးလိုက်ပါတယ်"
            : "$currentUserName liked your story";

        var existingNoti = await FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: storyOwnerId)
            .where('senderId', isEqualTo: widget.currentUid)
            .where('message', isEqualTo: likeMessage)
            .get();

        await FirebaseFirestore.instance
            .collection('stories')
            .doc(storyDoc.id)
            .update({
          'likes': FieldValue.arrayUnion([widget.currentUid])
        });

        // 🌟 ကိုယ့် Story မဟုတ်ရင် + အရင်က Noti တစ်ခါမှ မပို့ရသေးရင်မှ Noti ပို့မည်
        if (storyOwnerId != widget.currentUid &&
            storyOwnerId.isNotEmpty &&
            existingNoti.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'receiverId': storyOwnerId,
            'senderId': widget.currentUid,
            'message': likeMessage,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

          DocumentSnapshot receiverDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(storyOwnerId)
              .get();

          if (receiverDoc.exists && receiverDoc['fcmToken'] != null) {
            NotificationService.sendNotification(
              receiverDoc['fcmToken'],
              likeMessage,
              isMm ? "Story Liked!" : "Story Liked!",
              'message',
            );
          }
        }
      }
    } catch (e) {
      print("Like Error: $e");
    }

    if (mounted) {
      setState(() {
        _isPaused = false;
        _animController?.forward();
      });
    }
  }

  @override
  void dispose() {
    _animController?.dispose();
    _storyPageController.dispose();
    super.dispose();
  }

  Widget _buildViewerMediaLayout(Map<String, dynamic> story) {
    List<dynamic> mediaItems = story['mediaItems'] ?? [];
    String singleMediaUrl = story['mediaUrl'] ?? '';

    if (mediaItems.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var item in mediaItems)
            Positioned(
              left: (item['x'] ?? 50.0).toDouble(),
              top: (item['y'] ?? 150.0).toDouble(),
              child: Transform.scale(
                scale: (item['scale'] ?? 1.0).toDouble(),
                child: _buildViewerStyledMediaContainer(
                    item, story, singleMediaUrl),
              ),
            ),
        ],
      );
    }

    return Image.network(
      singleMediaUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildViewerStyledMediaContainer(Map<String, dynamic> item,
      Map<String, dynamic> story, String singleMediaUrl) {
    String shape = item['shape'] ?? 'rectangle';

    // 🌟 index မှာ null ဖြစ်နေရင် 0 လို့ အတိအကျ သတ်မှတ်ပေးခြင်း
    int itemIndex = item['index'] != null ? (item['index'] as num).toInt() : 0;

    List<dynamic> mediaUrls = story['mediaUrls'] ?? [];

    String imageUrl = mediaUrls.isNotEmpty && mediaUrls.length > itemIndex
        ? mediaUrls[itemIndex]
        : singleMediaUrl;

    if (shape == 'circle') {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
                blurRadius: 6, color: Colors.black45, offset: Offset(2, 2))
          ],
        ),
        child: ClipOval(
          child: Image.network(imageUrl, fit: BoxFit.cover),
        ),
      );
    } else if (shape == 'heart') {
      return ClipPath(
        clipper: HeartClipperViewer(),
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 6, color: Colors.black45, offset: Offset(2, 2))
            ],
          ),
          child: Image.network(imageUrl, fit: BoxFit.cover),
        ),
      );
    }

    return Container(
      width: 200,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(blurRadius: 6, color: Colors.black45, offset: Offset(2, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(imageUrl, fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // လက်ရှိ Story ရဲ့ Document ID ကို ယူမည်
    var initialStoryDoc = widget.stories[_currentStoryIndex];

    // 🌟 StreamBuilder ထည့်သွင်းပေးလိုက်ခြင်းဖြင့် Database မှာ Like ပြောင်းလဲမှုရှိတာနဲ့ UI ပါ ချက်ချင်းပြောင်းလဲသွားပါမည်
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('stories')
          .doc(initialStoryDoc.id)
          .snapshots(),
      builder: (context, snapshot) {
        // Data ရလာပါက Real-time data ကို သုံးမည်၊ မရှိသေးရင် Initial data ကို ယာယီသုံးမည်
        var storyDoc = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!
            : initialStoryDoc;

        var story = storyDoc.data() as Map<String, dynamic>;
        String mediaUrl = story['mediaUrl'] ?? '';
        String storyUid = story['uid'] ?? '';
        String userName = story['userName'] ?? 'အသုံးပြုသူ';
        String userImage = story['userImage'] ?? '';
        bool isVideo = _isVideoFile(mediaUrl);

        List<dynamic> likes = story['likes'] ?? [];
        bool isLikedByMe = likes.contains(widget.currentUid);

        return Container(
          decoration: themeProvider.getBackgroundDecoration(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: mediaUrl.isNotEmpty
                    ? (isVideo
                        ? StoryVideoPlayer(
                            key: ValueKey(mediaUrl),
                            videoUrl: mediaUrl,
                            onVideoEnded: () {
                              if (!_isPaused) _goToNextStory();
                            },
                            onPlayPauseChanged: (isPlaying) {
                              setState(() {
                                _isPaused = !isPlaying;
                                if (_isPaused) {
                                  _animController?.stop();
                                } else {
                                  _animController?.forward();
                                }
                              });
                            },
                          )
                        : _buildViewerMediaLayout(story))
                    : ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Text(
                            isMm ? "ဖိုင် မရှိပါ" : "No file found",
                            style: const TextStyle(color: Colors.white),
                          );
                        },
                      ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              if (story.containsKey('caption') &&
                  story['caption'].toString().isNotEmpty)
                Positioned(
                  left: (story['captionX'] ?? 50.0).toDouble(),
                  top: (story['captionY'] ?? 400.0).toDouble(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      story['caption'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                              blurRadius: 4,
                              color: Colors.black,
                              offset: Offset(1, 1))
                        ],
                      ),
                    ),
                  ),
                ),
              if (story.containsKey('audioUrl') &&
                  story['audioUrl'] != null &&
                  story['audioUrl'].toString().isNotEmpty)
                Positioned(
                  top: 100,
                  left: 16,
                  child: PostAudioPlayer(audioUrl: story['audioUrl']),
                ),
              if (story.containsKey('stickers') && story['stickers'] != null)
                ...((story['stickers'] as List<dynamic>).map((sticker) {
                  var data = sticker as Map<String, dynamic>;
                  double dx = (data['x'] ?? 100.0).toDouble();
                  double dy = (data['y'] ?? 200.0).toDouble();
                  String content = data['content'] ?? '';
                  String type = data['type'] ?? 'text';

                  return Positioned(
                    left: dx,
                    top: dy,
                    child: Container(
                      padding: type == 'text'
                          ? const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6)
                          : EdgeInsets.zero,
                      decoration: type == 'text'
                          ? BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: Colors.white54, width: 1),
                            )
                          : null,
                      child: Text(
                        content,
                        style: TextStyle(
                          fontSize: type == 'emoji' ? 36 : 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                                blurRadius: 4,
                                color: Colors.black,
                                offset: Offset(1, 1))
                          ],
                        ),
                      ),
                    ),
                  );
                })),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (_) {
                        _isPaused = true;
                        _animController?.stop();
                      },
                      onTapUp: (_) {
                        _isPaused = false;
                        _animController?.forward();
                      },
                      onTap: _goToPreviousStory,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (_) {
                        _isPaused = true;
                        _animController?.stop();
                      },
                      onTapUp: (_) {
                        _isPaused = false;
                        _animController?.forward();
                      },
                      onTap: _goToNextStory,
                    ),
                  ),
                ],
              ),
              // Like Button
              Positioned(
                bottom: 24,
                right: 20,
                child: Row(
                  children: [
                    if (likes.isNotEmpty)
                      Text(
                        "${likes.length}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _toggleStoryLike(storyDoc),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLikedByMe ? Icons.favorite : Icons.favorite_border,
                          color: isLikedByMe ? Colors.red : Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children:
                          List.generate(widget.stories.length, (barIndex) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _currentStoryIndex == barIndex
                                ? AnimatedBuilder(
                                    animation: _animController ??
                                        kAlwaysDismissedAnimation,
                                    builder: (context, child) {
                                      return LinearProgressIndicator(
                                        value: _animController?.value ?? 0,
                                        backgroundColor:
                                            Colors.white.withOpacity(0.4),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      );
                                    },
                                  )
                                : LinearProgressIndicator(
                                    value: barIndex < _currentStoryIndex
                                        ? 1.0
                                        : 0.0,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.4),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OtherProfilePage(
                                    userId: storyUid,
                                    userName: userName,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey,
                                  backgroundImage: userImage.isNotEmpty
                                      ? NetworkImage(userImage)
                                      : null,
                                  child: userImage.isEmpty
                                      ? const Icon(Icons.person,
                                          color: Colors.white, size: 20)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(storyUid)
                                        .get(),
                                    builder: (context, userSnapshot) {
                                      String role = 'member';
                                      if (userSnapshot.hasData &&
                                          userSnapshot.data!.exists) {
                                        var uData = userSnapshot.data!.data()
                                            as Map<String, dynamic>;
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
                                          name: userName,
                                          role: role,
                                          fontSize: 15,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (storyUid == widget.currentUid)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.white),
                            onOpened: () {
                              _isPaused = true;
                              _animController?.stop();
                            },
                            onCanceled: () {
                              _isPaused = false;
                              _animController?.forward();
                            },
                            onSelected: (value) async {
                              if (value == 'delete') {
                                final isMm = isMyanmarNotifier.value;
                                bool? confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(isMm
                                        ? "Story ဖျက်မည်"
                                        : "Delete Story"),
                                    content: Text(
                                      isMm
                                          ? "ဤ Story ကို ဖျက်ရန် သေချာပါသလား?"
                                          : "Are you sure you want to delete this story?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                            isMm ? "မလုပ်တော့ပါ" : "Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red),
                                        child: Text(
                                          isMm ? "ဖျက်မည်" : "Delete",
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  try {
                                    if (mediaUrl.isNotEmpty) {
                                      await R2Service.deleteFile(mediaUrl);
                                    }
                                    await FirebaseFirestore.instance
                                        .collection('stories')
                                        .doc(storyDoc.id)
                                        .delete();

                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isMm
                                              ? "Story ကို ဖျက်ပြီးပါပြီ"
                                              : "Story deleted successfully",
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    print("Delete Error: $e");
                                  }
                                } else {
                                  _isPaused = false;
                                  _animController?.forward();
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: isMyanmarNotifier,
                                  builder: (context, isMm, child) {
                                    return Row(
                                      children: [
                                        const Icon(Icons.delete,
                                            color: Colors.red, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          isMm
                                              ? "Story ဖျက်မည်"
                                              : "Delete Story",
                                          style: const TextStyle(
                                              color: Colors.red),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 28),
                          onPressed: widget.onBackPressed,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 🌟 Viewer အတွက် အသဲပုံ (Heart Shape) Clipper
class HeartClipperViewer extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double width = size.width;
    double height = size.height;
    path.moveTo(width / 2, height / 5);
    path.cubicTo(width * 5 / 6, height / 20, width, height / 3, width / 2,
        height * 4 / 5);
    path.cubicTo(0, height / 3, width / 6, height / 20, width / 2, height / 5);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// 🎥 ဗီဒီယိုပြသရန် Player
class StoryVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onVideoEnded;
  final ValueChanged<bool> onPlayPauseChanged;

  const StoryVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.onVideoEnded,
    required this.onPlayPauseChanged,
  });

  @override
  State<StoryVideoPlayer> createState() => _StoryVideoPlayerState();
}

class _StoryVideoPlayerState extends State<StoryVideoPlayer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final htmlContent = '''
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="margin:0;background-color:black;display:flex;justify-content:center;align-items:center;height:100vh;overflow:hidden;">
          <video id="storyVideo" autoplay playsinline webkit-playsinline style="width:100%;height:100%;object-fit:cover;" onclick="togglePlayPauseAndNotify()">
            <source src="${widget.videoUrl}" type="video/mp4">
            Your browser does not support the video tag.
          </video>
          <script>
            var video = document.getElementById('storyVideo');
            video.muted = false;
            
            var playPromise = video.play();
            if (playPromise !== undefined) {
              playPromise.catch(function(error) {
                video.muted = true;
                video.play().then(function() {
                  video.muted = false;
                });
              });
            }

            video.onended = function() {
              storyChannel.postMessage('videoEnded');
            };

            function togglePlayPauseAndNotify() {
              if (video.paused) {
                video.play();
                storyChannel.postMessage('play');
              } else {
                video.pause();
                storyChannel.postMessage('pause');
              }
            }
          </script>
        </body>
      </html>
    ''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller
      ..addJavaScriptChannel(
        'storyChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'videoEnded') {
            widget.onVideoEnded();
          } else if (message.message == 'pause') {
            widget.onPlayPauseChanged(false);
          } else if (message.message == 'play') {
            widget.onPlayPauseChanged(true);
          }
        },
      )
      ..loadHtmlString(htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _controller),
      ],
    );
  }
}

class AddStoryButton extends StatelessWidget {
  final String myProfileImage;
  final bool hasMyStory;
  final VoidCallback? onStoryTap;

  const AddStoryButton({
    super.key,
    required this.myProfileImage,
    required this.hasMyStory,
    this.onStoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    Color textColor = themeProvider.getTextColor();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: GestureDetector(
        onTap: () {
          // တကယ်လို့ Story ရှိပြီးသားဆိုရင် နှိပ်ရင် ဝင်ကြည့်မယ်၊ မရှိရင် အသစ်တင်မယ်
          if (hasMyStory && onStoryTap != null) {
            onStoryTap!();
          } else {
            _showStoryCreationSheet(context);
          }
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 🌟 Story တင်ထားရင် အဝိုင်းပတ်လည် အရောင်စပ်ပြမယ်၊ မတင်ရသေးရင် အရောင်မပါဘူး
                gradient: hasMyStory
                    ? const LinearGradient(
                        colors: [Colors.red, Colors.orange, Colors.purple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
              ),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey,
                    backgroundImage: (myProfileImage.isNotEmpty)
                        ? NetworkImage(myProfileImage)
                        : null,
                    child: (myProfileImage.isEmpty)
                        ? const Icon(Icons.person,
                            size: 20, color: Colors.white)
                        : null,
                  ),
                  // 🌟 အမြဲတမ်း (သို့မဟုတ် Story ရှိသည်ဖြစ်စေ၊ မရှိသည်ဖြစ်စေ) + ခလုတ်လေးကို ထည့်ပြချင်ရင် ဒီအတိုင်းထားနိုင်ပါတယ်
                  GestureDetector(
                    onTap: () => _showStoryCreationSheet(
                        context), // + လายကို နှိပ်ရင် အသစ်တင်ရန် ပေါ်မည်
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child:
                          const Icon(Icons.add, size: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 1),
            ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Text(
                  isMm ? "သင့် Story" : "Your Story",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ... AddStoryButton Class ထဲမှာ ရှိတဲ့ ...

  void _showStoryCreationSheet(BuildContext parentContext) {
    final themeProvider =
        Provider.of<ThemeProvider>(parentContext, listen: false);
    final bool isDarkMode = themeProvider.currentTheme != 'Default';
    final Color backgroundColor =
        isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: backgroundColor,
      // 🌟 အောက်ခြေ Gesture Area ကိုပါ Sheet က ယူနိုင်အောင် wrap လုပ်မည်
      useSafeArea: true,
      isScrollControlled: true, // Sheet အရွယ်အစားကို Content အလိုက် ညှိရန်
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final sheetThemeProvider = Provider.of<ThemeProvider>(context);
        final Color sheetTextColor = sheetThemeProvider.getTextColor();

        // 🌟 SafeArea ဖြင့် Wrap လုပ်ပြီး အောက်ခြေ Padding ထည့်မည်
        return SafeArea(
          bottom: true, // အောက်ခြေ System Bar ကို ရှောင်ရန်
          child: Padding(
            // 🌟 bottom: 16 ကနေ bottom: 24 သို့ တိုးမြှင့်ပြီး ပိုခွာလိုက်ပါ
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Column(
                  mainAxisSize: MainAxisSize.min, // Content ရှိသလောက်ပဲ ယူရန်
                  children: [
                    Text(
                      isMm ? "Story တင်ရန် ရွေးချယ်ပါ" : "Select Story Type",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: sheetTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.photo, color: Colors.blue),
                      title: Text(
                        isMm ? "ဓာတ်ပုံ Story တင်မည်" : "Upload Photo Story",
                        style: TextStyle(color: sheetTextColor),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadMedia(parentContext, isVideo: false);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.videocam, color: Colors.orange),
                      title: Text(
                        isMm
                            ? "ဗီဒီယို Story တင်မည် (အများဆုံး ၃၀ စက္ကန့်)"
                            : "Upload Video Story (Max 30 seconds)",
                        style: TextStyle(color: sheetTextColor),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadMedia(parentContext, isVideo: true);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

// ... _pickAndUploadMedia Function ဆက်သွားမည် ...

  Future<void> _pickAndUploadMedia(BuildContext context,
      {required bool isVideo}) async {
    // ဓာတ်ပုံ/ဗီဒီယို ရွေးချယ်သည့် လုပ်ဆောင်ချက်များ...
    try {
      final picker = ImagePicker();
      late File file;
      late XFile pickedMedia;

      if (isVideo) {
        final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
        if (pickedFile != null) {
          pickedMedia = pickedFile;
          file = File(pickedFile.path);
          MediaInfo? mediaInfo = await VideoCompress.getMediaInfo(file.path);
          if (mediaInfo.duration != null && mediaInfo.duration! > 30000) {
            if (!context.mounted) return;
            final isMm = isMyanmarNotifier.value;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isMm
                      ? "Story ဗီဒီယိုသည် စက္ကန့် ၃၀ ထက် မကျော်ရပါ။"
                      : "Story video must not exceed 30 seconds.",
                ),
              ),
            );
            return;
          }
        } else {
          return;
        }
      } else {
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          pickedMedia = pickedFile;
          file = File(pickedFile.path);
        } else {
          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 100));
      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoryEditorScreen(
            mediaFile: file,
            isVideo: isVideo,
            mediaFiles: [pickedMedia],
          ),
        ),
      );
    } catch (e) {
      print("Pick Media Error: $e");
    }
  }
}

class StoryAvatarItem extends StatelessWidget {
  final String userName;
  final String userImage;
  final VoidCallback onTap;

  const StoryAvatarItem({
    super.key,
    required this.userName,
    required this.userImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    Color textColor = themeProvider.getTextColor();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.orange, Colors.purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                backgroundImage:
                    (userImage.isNotEmpty) ? NetworkImage(userImage) : null,
                child: (userImage.isEmpty)
                    ? const Icon(Icons.person, size: 20, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 1),
            SizedBox(
              width: 50,
              child: Text(
                userName,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
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
