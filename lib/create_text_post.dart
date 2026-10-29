// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:flutter_linkify/flutter_linkify.dart'; // လင့်ခ်များအတွက်
import 'package:url_launcher/url_launcher.dart'; // လင့်ခ်ဖွင့်ရန်
import 'package:karma/services/r2_service.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:karma/widgets/banner_ad_widget.dart'; // Banner Ad အတွက်
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart'; // Theme Provider အတွက်

// -------------------------------------------------------------
// Expandable Text Widget (Linkify နှင့် Dark/Light Mode Support)
// -------------------------------------------------------------
class ExpandableText extends StatefulWidget {
  final String text;
  final int trimWordCount;
  final Color textColor;

  const ExpandableText({
    super.key,
    required this.text,
    this.trimWordCount = 40,
    required this.textColor,
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
            final Uri url = Uri.parse(link.url);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              print('Could not launch $url');
            }
          },
          text: displayedText,
          style: TextStyle(color: widget.textColor, fontSize: 16),
          linkStyle: const TextStyle(
            color: Colors.blueAccent,
            decoration: TextDecoration.underline,
          ),
        ),
        if (isLongText)
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _isExpanded ? "အကျဉ်းချုပ်ပြမည်" : "ဆက်ဖတ်ရန်...",
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------
// CreatePostPage (ThemeProvider, Mention Support, Media, & Ad Banner)
// -------------------------------------------------------------
class CreatePostPage extends StatefulWidget {
  final String initialMode;
  const CreatePostPage({super.key, required this.initialMode});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _textController = TextEditingController();
  final List<File> _selectedImages = [];
  File? _selectedVideo;
  bool _isVideo = false;
  bool _isLoading = false;
  final List<String> _taggedUserIds = [];

  // 🌟 Hashtag Suggestions အတွက် လိုအပ်သော Variable များ
  List<String> _hashtagSuggestions = [];
  bool _showSuggestions = false;

  // 🌟 စာရိုက်နေစဉ် Hashtag ရှာဖွေပေးမည့် Function
  void _onTextChanged(String value) async {
    final RegExp regExp = RegExp(r"\B#([\w\u0080-\uFFFF]+)$");
    final match = regExp.firstMatch(value);

    if (match != null) {
      String query = match.group(1)!; // '#' နောက်က စာသားကို ယူမည် (ဥပမာ - app)
      await _fetchHashtagSuggestions(query);
    } else {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  // 🌟 Firestore မှ Hashtag များကို ရှာယူခြင်း
  Future<void> _fetchHashtagSuggestions(String query) async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('posts').get();

      Set<String> matchedTags = {};
      for (var doc in snapshot.docs) {
        List<dynamic> tags = doc['hashtags'] ?? [];
        for (var tag in tags) {
          String cleanTag = tag.toString().replaceAll('#', '');
          if (cleanTag.toLowerCase().contains(query.toLowerCase())) {
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

  Future<void> _pickMultipleImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedVideo = null;
        _isVideo = false;
        for (var pickedFile in pickedFiles) {
          _selectedImages.add(File(pickedFile.path));
        }
      });
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final picker = ImagePicker();
    final pickedFile = isVideo
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);

    if (pickedFile != null) {
      File file = File(pickedFile.path);

      if (isVideo) {
        try {
          MediaInfo? mediaInfo = await VideoCompress.getMediaInfo(file.path);
          if (mediaInfo.duration != null && mediaInfo.duration! > 900000) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("ဗီဒီယိုသည် ၁၅ မိနစ်ထက် မကျော်ရပါ။")),
            );
            return;
          }
        } catch (e) {
          print("Media Info Error: $e");
        }

        setState(() {
          _selectedImages.clear();
          _selectedVideo = file;
          _isVideo = true;
        });
      } else {
        setState(() {
          _selectedImages.add(file);
        });
      }
    }
  }

  void _showMediaSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("ပုံ သို့မဟုတ် ဗီဒီယို ရယူရန်",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
            title: const Text("ဂယ်လီယာမှ ပုံများ ရွေးမည်"),
            onTap: () {
              Navigator.pop(context);
              _pickMultipleImages();
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library, color: Colors.orange),
            title: const Text("ဂယ်လီယာမှ ဗီဒီယိုရွေးမည်"),
            onTap: () {
              Navigator.pop(context);
              _pickMedia(ImageSource.gallery, isVideo: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.green),
            title: const Text("ကင်မရာဖြင့် ပုံရိုက်မည်"),
            onTap: () {
              Navigator.pop(context);
              _pickMedia(ImageSource.camera, isVideo: false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Colors.redAccent),
            title: const Text("ကင်မရာဖြင့် ဗီဒီယိုရိုက်မည်"),
            onTap: () {
              Navigator.pop(context);
              _pickMedia(ImageSource.camera, isVideo: true);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _submitPost() async {
    if (_textController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("ကျေးဇူးပြု၍ စာ သို့မဟုတ် ပုံ/ဗီဒီယို ထည့်ပါ။")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> mediaUrls = [];
      String? singleMediaUrl;

      if (_selectedImages.isNotEmpty) {
        for (var imageFile in _selectedImages) {
          String? url = await R2Service.uploadFile(imageFile, 'posts_media');
          if (url != null) {
            mediaUrls.add(url);
          }
        }
      }

      if (_selectedVideo != null && _isVideo) {
        File fileToUpload = _selectedVideo!;
        final compressedVideo = await VideoCompress.compressVideo(
          _selectedVideo!.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );

        if (compressedVideo != null && compressedVideo.file != null) {
          fileToUpload = compressedVideo.file!;
        }

        singleMediaUrl =
            await R2Service.uploadFile(fileToUpload, 'posts_media');
        await VideoCompress.deleteAllCache();
      }

      String uid = FirebaseAuth.instance.currentUser!.uid;
      User? currentUser = FirebaseAuth.instance.currentUser;
      String userName = currentUser?.displayName ?? "အသုံးပြုသူ";

      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      String userImage = '';
      String userRole = 'member';
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          userName = data['displayName'] ??
              data['name'] ??
              data['userName'] ??
              userName;
          userImage = data['profileImageUrl'] ??
              data['profileImage'] ??
              data['photoURL'] ??
              currentUser?.photoURL ??
              '';
          userRole = data['role'] ?? 'member';
        }
      }
      final String normalizedRole = userRole.trim().toLowerCase();
      bool isGolden = (normalizedRole == 'admin' ||
          normalizedRole == 'vip' ||
          normalizedRole == 'gold_user');

      final RegExp hashtagRegExp = RegExp(r'\B#\w+[\w_-]*');
      List<String> extractedHashtags = hashtagRegExp
          .allMatches(_textController.text)
          .map((match) => match.group(0)!.toLowerCase())
          .toSet()
          .toList();

      await FirebaseFirestore.instance.collection('posts').add({
        'uid': uid,
        'userName': userName,
        'userImage': userImage,
        'role': userRole,
        'isGolden': isGolden,
        'text': _textController.text.trim(),
        'mediaUrls': mediaUrls,
        'mediaUrl':
            singleMediaUrl ?? (mediaUrls.isNotEmpty ? mediaUrls.first : ''),
        'likes': [],
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'taggedUserIds': _taggedUserIds,
        'hashtags': extractedHashtags,
        'createdAt': FieldValue.serverTimestamp(),
        'viewCount': 0,
        'viewedUserIds': [],
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      print("Post Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("တင်၍မအောင်မြင်ပါ။ Error: $e")),
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
    bool isDark = (themeProvider.currentTheme != 'Default');
    Color textColor = themeProvider.getTextColor();
    String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: Text(
            'ပို့စ်အသစ် ဖန်တီးရန်',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
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
                : TextButton(
                    onPressed: _submitPost,
                    child: Text(
                      "တင်မည်",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  )
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String displayName = "အသုံးပြုသူ";
                        String? profileImg;
                        String role = 'member';

                        if (snapshot.hasData && snapshot.data!.exists) {
                          var data =
                              snapshot.data!.data() as Map<String, dynamic>?;
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
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // 🌟 TextField နှင့် Suggestion List ကို ပေါင်းစပ်ထားခြင်း
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _textController,
                          maxLines: 4,
                          onChanged: (value) {
                            _onTextChanged(
                                value); // 🌟 onChanged ကို ချိတ်ဆက်ခြင်း
                          },
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText:
                                "ယနေ့ သင့်ရဲ့ အတွေးအမြင်များကို ဝေမျှပါ (#hashtag သို့မဟုတ် @ ဖြင့် Mention ခေါ်နိုင်သည်)...",
                            hintStyle: TextStyle(
                                color:
                                    isDark ? Colors.white60 : Colors.black54),
                            border: InputBorder.none,
                          ),
                        ),

                        // 🌟 Hashtag Suggestion ပေါ်မည့် Box လေး
                        if (_showSuggestions)
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color:
                                  isDark ? Colors.grey[850] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400),
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
                                    // Suggestion ထဲက ஒன்றை နှိပ်လိုက်ရင် စာသားထဲသို့ အစားထိုးထည့်ပေးရန်
                                    String currentText = _textController.text;
                                    int lastHashIndex =
                                        currentText.lastIndexOf('#');
                                    if (lastHashIndex != -1) {
                                      String newText =
                                          "${currentText.substring(0, lastHashIndex)}$tag ";
                                      _textController.text = newText;
                                      _textController.selection =
                                          TextSelection.fromPosition(
                                        TextPosition(
                                            offset:
                                                _textController.text.length),
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
                      ],
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.red.shade900.withOpacity(0.3)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "⚠️ သတိပေးချက် - ၁၈+ (NSFW) ပုံများ၊ ဗီဒီယိုများနှင့် မသင့်လျော်သော အကြောင်းအရာများ တင်ခြင်းကို တင်းကြပ်စွာ တားမြစ်သည်။ စည်းကမ်းဖောက်ဖျက်ပါက အကောင့်ပိတ်သိမ်းမည်။",
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _selectedImages.isEmpty && _selectedVideo == null
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
                                  Text("ပုံ သို့မဟုတ် ဗီဒီယို ထည့်ရန်",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey)),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              if (_selectedVideo != null && _isVideo)
                                Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    Container(
                                      height: 220,
                                      width: double.infinity,
                                      color: Colors.black12,
                                      child: const Center(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.videocam,
                                                size: 30,
                                                color: Colors.blueAccent),
                                            SizedBox(width: 8),
                                            Text("ဗီဒီယို ဖိုင်ရွေးပြီးပါပြီ",
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const CircleAvatar(
                                        backgroundColor: Colors.black54,
                                        child: Icon(Icons.close,
                                            color: Colors.white),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedVideo = null;
                                          _isVideo = false;
                                        });
                                      },
                                    ),
                                  ],
                                )
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: _selectedImages.length,
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      alignment: Alignment.topRight,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.file(
                                            _selectedImages[index],
                                            height: double.infinity,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Colors.black54,
                                            child: Icon(Icons.close,
                                                size: 16, color: Colors.white),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _selectedImages.removeAt(index);
                                            });
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showMediaSourceActionSheet(context),
                                icon: const Icon(Icons.add_a_photo),
                                label: const Text("ဓာတ်ပုံ/ဗီဒီယို ထပ်ထည့်ရန်"),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}
