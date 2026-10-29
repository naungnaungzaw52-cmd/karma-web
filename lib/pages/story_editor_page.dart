// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
// ignore: unused_import
import 'package:karma/services/r2_service.dart';
import 'package:karma/main.dart'; // 🌟 isMyanmarNotifier အတွက် ထည့်သွင်းခြင်း
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class StoryEditorScreen extends StatefulWidget {
  final List<dynamic> mediaFiles;
  final bool isVideo;

  const StoryEditorScreen({
    super.key,
    required this.mediaFiles,
    required this.isVideo,
    required File mediaFile,
  });

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  final TextEditingController _textController = TextEditingController();

  String _overlayText = "";
  Color _textColor = Colors.white;
  Offset _textOffset = const Offset(150, 300);
  double _textScale = 1.0;

  File? _selectedAudio;
  double _audioStartSecond = 0.0;

  final List<Map<String, dynamic>> _mediaItems = [];
  final List<Map<String, dynamic>> _stickers = [];
  bool _isUploading = false;

  final List<Color> _colors = [
    Colors.white,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.pink,
    Colors.orange,
    Colors.red,
    Colors.purple,
  ];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.mediaFiles.length; i++) {
      _mediaItems.add({
        'file': widget.mediaFiles[i],
        'offset': Offset(50.0 + (i * 30), 150.0 + (i * 50)),
        'scale': 1.0,
        'shape': 'rectangle',
      });
    }
  }

  // 🎵 သီချင်း (Audio) ဖိုင်ရွေးချယ်ရန်နှင့် ဖြတ်တောက်ရန်
  Future<void> _pickAudio() async {
    bool isMm = isMyanmarNotifier.value;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        File audioFile = File(result.files.single.path!);

        AudioPlayer tempPlayer = AudioPlayer();
        await tempPlayer.setSource(DeviceFileSource(audioFile.path));
        Duration? totalDuration = await tempPlayer.getDuration();
        await tempPlayer.dispose();

        double maxSeconds =
            totalDuration != null ? totalDuration.inSeconds.toDouble() : 60.0;
        double startSecond = 0.0;
        double durationSeconds = 20.0;

        if (!mounted) return;

        await showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(isMm
                      ? "သီချင်း ဖြတ်တောက်ရန် (Audio Trim)"
                      : "Trim Audio"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMm
                            ? "သီချင်းစတင်မည့် စက္ကန့်ကို ရွေးချယ်ပါ (စုစုပေါင်း: ${maxSeconds.toInt()} စက္ကန့်)"
                            : "Select start second (Total: ${maxSeconds.toInt()}s)",
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Text(
                          isMm
                              ? "စတင်မည့်နေရာ: ${startSecond.toInt()} စက္ကန့်"
                              : "Start at: ${startSecond.toInt()}s",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: startSecond,
                        min: 0.0,
                        max: maxSeconds > 20 ? maxSeconds - 20 : 0.0,
                        divisions:
                            maxSeconds > 20 ? (maxSeconds - 20).toInt() : 1,
                        label: "${startSecond.toInt} s",
                        onChanged: (val) {
                          setDialogState(() {
                            startSecond = val;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                          isMm
                              ? "ကြာချိန် (Duration): ${durationSeconds.toInt()} စက္ကန့်"
                              : "Duration: ${durationSeconds.toInt()}s",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: durationSeconds,
                        min: 5.0,
                        max: 30.0,
                        divisions: 25,
                        label: "${durationSeconds.toInt} s",
                        onChanged: (val) {
                          setDialogState(() {
                            durationSeconds = val;
                          });
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isMm ? "မလုပ်တော့ပါ" : "Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isMm ? "အတည်ပြုမည်" : "Confirm"),
                    ),
                  ],
                );
              },
            );
          },
        );

        setState(() {
          _selectedAudio = audioFile;
          _audioStartSecond = startSecond;
        });
      }
    } catch (e) {
      print("Audio Picker Error: $e");
    }
  }

  // ⏰ အချိန် Sticker ထည့်ရန်
  void _addTimeSticker() {
    String currentTime = DateFormat('hh:mm a').format(DateTime.now());
    setState(() {
      _stickers.add({
        'type': 'text',
        'content': '⏰ $currentTime',
        'offset': const Offset(150, 250),
        'scale': 1.0,
      });
    });
  }

  Future<void> _addMoreImages() async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var pickedFile in pickedFiles) {
          _mediaItems.add({
            'file': pickedFile,
            'offset': const Offset(100, 200),
            'scale': 1.0,
            'shape': 'rectangle',
          });
          widget.mediaFiles.add(pickedFile);
        }
      });
    }
  }

  // 😊 Emoji Sticker ရွေးရန် Sheet
  void _showEmojiPickerSheet(Color textColor) {
    bool isMm = isMyanmarNotifier.value;
    List<String> popularEmojis = [
      '🔥',
      '❤️',
      '😍',
      '😂',
      '👍',
      '✨',
      '🎉',
      '😎',
      '💯',
      '🌟',
      '🥰',
      '🚀',
      '📍',
      '📌',
      '☕',
      '🍻'
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isMm ? "Sticker များ ရွေးချယ်ရန်" : "Select Stickers",
                  style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: popularEmojis.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _stickers.add({
                            'type': 'emoji',
                            'content': popularEmojis[index],
                            'offset': const Offset(180, 300),
                            'scale': 1.0,
                          });
                        });
                      },
                      child: Center(
                        child: Text(
                          popularEmojis[index],
                          style: const TextStyle(fontSize: 36),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShapePicker(int index) {
    bool isMm = isMyanmarNotifier.value;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isMm ? "Frame ပုံစံ ရွေးချယ်ရန်" : "Select Frame Shape",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _shapeButton(index, isMm ? 'စတုဂံ' : 'Rectangle', 'rectangle',
                      Icons.crop_square),
                  _shapeButton(index, isMm ? 'ဝိုင်းပုံ' : 'Circle', 'circle',
                      Icons.circle),
                  _shapeButton(index, isMm ? 'အသဲပုံ' : 'Heart', 'heart',
                      Icons.favorite),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shapeButton(int index, String label, String shapeKey, IconData icon) {
    return InkWell(
      onTap: () {
        setState(() {
          _mediaItems[index]['shape'] = shapeKey;
        });
        Navigator.pop(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Colors.blueAccent),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }

  // ☁️ Firebase သို့ Story တင်ရန် (Story Editor အတွက် သီးသန့် Bytes ပို့နည်း)
  // ☁️ Firebase သို့ Story တင်ရန် (အမှန်ကန်ဆုံး ပြင်ဆင်ပြီး)
  Future<void> _uploadStory() async {
    setState(() {
      _isUploading = true;
    });

    try {
      List<String> uploadedUrls = [];

      for (var item in _mediaItems) {
        var fileObj = item['file'];
        Uint8List? fileBytes;
        String fileName = "story_${DateTime.now().millisecondsSinceEpoch}.jpg";

        // 🌟 XFile ရော File ပါ အလွယ်တကူ bytes ထုတ်ယူရန်
        if (fileObj is XFile) {
          fileBytes = await fileObj.readAsBytes();
          fileName = fileObj.name;
        } else if (fileObj is File) {
          fileBytes = await fileObj.readAsBytes();
          fileName = fileObj.path.split('/').last;
        }

        if (fileBytes != null) {
          var request = http.MultipartRequest(
            'POST',
            Uri.parse(
                "https://karma-api777.naungnaungzaw52.workers.dev/upload"),
          );
          request.fields['folder'] = 'stories_media';
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: fileName,
              contentType: MediaType('image', 'jpeg'),
            ),
          );

          var streamedResponse = await request.send();
          var response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200) {
            var data = jsonDecode(response.body);
            if (data['fileUrl'] != null) {
              uploadedUrls.add(data['fileUrl']);
            }
          } else {
            print("Story Upload Failed: ${response.body}");
          }
        }
      }

      String audioUrl = '';
      if (_selectedAudio != null) {
        Uint8List audioBytes = await _selectedAudio!.readAsBytes();
        String audioName = "audio_${DateTime.now().millisecondsSinceEpoch}.mp3";

        var audioReq = http.MultipartRequest(
          'POST',
          Uri.parse("https://karma-api777.naungnaungzaw52.workers.dev/upload"),
        );
        audioReq.fields['folder'] = 'stories_audio';
        audioReq.files.add(
          http.MultipartFile.fromBytes(
            'file',
            audioBytes,
            filename: audioName,
            contentType: MediaType('audio', 'mpeg'),
          ),
        );

        var audioStreamed = await audioReq.send();
        var audioRes = await http.Response.fromStream(audioStreamed);
        if (audioRes.statusCode == 200) {
          var audioData = jsonDecode(audioRes.body);
          audioUrl = audioData['fileUrl'] ?? '';
        }
      }

      if (uploadedUrls.isNotEmpty) {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        bool isMm = isMyanmarNotifier.value;
        String userName = FirebaseAuth.instance.currentUser?.displayName ??
            (isMm ? "အသုံးပြုသူ" : "User");

        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        String userImage = '';
        if (userDoc.exists) {
          var data = userDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('profileImageUrl')) {
            userImage = data['profileImageUrl'] ?? '';
          }
        }

        await FirebaseFirestore.instance.collection('stories').add({
          'uid': uid,
          'userName': userName,
          'userImage': userImage,
          'mediaUrl': uploadedUrls.first,
          'mediaUrls': uploadedUrls,
          'audioUrl': audioUrl,
          'audioStartSecond': _audioStartSecond,
          'layoutType': 'freeform',
          'isVideo': widget.isVideo,
          'caption': _overlayText,
          'captionX': _textOffset.dx,
          'captionY': _textOffset.dy,
          'mediaItems': _mediaItems.map((item) {
            Offset offset = item['offset'];
            return {
              'x': offset.dx,
              'y': offset.dy,
              'scale': item['scale'],
              'shape': item['shape'] ?? 'rectangle',
            };
          }).toList(),
          'stickers': _stickers.map((sticker) {
            Offset offset = sticker['offset'];
            return {
              'type': sticker['type'],
              'content': sticker['content'],
              'x': offset.dx,
              'y': offset.dy,
              'scale': sticker['scale'],
            };
          }).toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt':
              Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
        });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isMm ? "Story တင်ပြီးပါပြီ။" : "Story posted successfully.")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      bool isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isMm
                ? "Story တင်၍မအောင်မြင်ပါ: $e"
                : "Failed to post story: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildStyledMediaContainer(Map<String, dynamic> item) {
    String shape = item['shape'] ?? 'rectangle';
    var fileObj = item['file'];

    // 🌟 Web နှင့် Mobile နှစ်ခုလုံးအတွက် Error မတက်စေရန် ပုံဖော်ခြင်း
    Widget imageWidget = kIsWeb
        ? FutureBuilder<Uint8List>(
            future: fileObj is XFile
                ? fileObj.readAsBytes()
                : (fileObj as File).readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Image.memory(snapshot.data!, fit: BoxFit.cover);
              }
              return const Center(child: CircularProgressIndicator());
            },
          )
        : Image.file(fileObj is File ? fileObj : File((fileObj as XFile).path),
            fit: BoxFit.cover);

    if (shape == 'circle') {
      return Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
                blurRadius: 6, color: Colors.black45, offset: Offset(2, 2))
          ],
        ),
        child: ClipOval(child: imageWidget),
      );
    } else if (shape == 'heart') {
      return ClipPath(
        clipper: HeartClipper(),
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 6, color: Colors.black45, offset: Offset(2, 2))
            ],
          ),
          child: imageWidget,
        ),
      );
    }

    return Container(
      width: 180,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(blurRadius: 6, color: Colors.black45, offset: Offset(2, 2))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: imageWidget,
      ),
    );
  }

  Widget _buildMediaLayout() {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (int i = 0; i < _mediaItems.length; i++)
          Positioned(
            left: _mediaItems[i]['offset'].dx,
            top: _mediaItems[i]['offset'].dy,
            child: GestureDetector(
              onScaleStart: (details) {
                _mediaItems[i]['baseScale'] = _mediaItems[i]['scale'];
              },
              onScaleUpdate: (details) {
                setState(() {
                  _mediaItems[i]['offset'] += details.focalPointDelta;
                  double baseScale = _mediaItems[i]['baseScale'] ?? 1.0;
                  _mediaItems[i]['scale'] =
                      (baseScale * details.scale).clamp(0.4, 2.5);
                });
              },
              onDoubleTap: () => _showShapePicker(i),
              onLongPress: () {
                setState(() {
                  _mediaItems.removeAt(i);
                });
              },
              child: Transform.scale(
                scale: _mediaItems[i]['scale'],
                child: _buildStyledMediaContainer(_mediaItems[i]),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    Color textColor = themeProvider.getTextColor();

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: ValueListenableBuilder<bool>(
            valueListenable: isMyanmarNotifier,
            builder: (context, isMm, child) {
              return Text(
                isMm ? "Story တည်းဖြတ်ရန်" : "Edit Story",
                style: TextStyle(color: textColor, fontSize: 16),
              );
            },
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.music_note, color: textColor),
                      onPressed: _pickAudio,
                      tooltip: isMm ? "သီချင်းထည့်ရန်" : "Add Music",
                    ),
                    IconButton(
                      icon: Icon(Icons.add_photo_alternate, color: textColor),
                      onPressed: _addMoreImages,
                      tooltip: isMm ? "ပုံထပ်ထည့်ရန်" : "Add More Photos",
                    ),
                    IconButton(
                      icon: Icon(Icons.access_time, color: textColor),
                      onPressed: _addTimeSticker,
                      tooltip: isMm ? "အချိန် Sticker" : "Time Sticker",
                    ),
                    IconButton(
                      icon:
                          Icon(Icons.sentiment_satisfied_alt, color: textColor),
                      onPressed: () => _showEmojiPickerSheet(textColor),
                      tooltip: isMm ? "Sticker များ" : "Stickers",
                    ),
                  ],
                );
              },
            ),
            _isUploading
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(color: textColor),
                  )
                : ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return TextButton(
                        onPressed: _uploadStory,
                        child: Text(
                          isMm ? "မျှဝေမည်" : "Share",
                          style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: widget.isVideo
                  ? const Center(
                      child:
                          Icon(Icons.videocam, size: 80, color: Colors.white))
                  : _buildMediaLayout(),
            ),
            if (_selectedAudio != null)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purpleAccent, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.music_note,
                          color: Colors.purpleAccent, size: 16),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          _selectedAudio!.path.split('/').last,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedAudio = null;
                          });
                        },
                        child: const Icon(Icons.close,
                            color: Colors.red, size: 14),
                      ),
                    ],
                  ),
                ),
              ),
            if (_overlayText.isNotEmpty)
              Positioned(
                left: _textOffset.dx,
                top: _textOffset.dy,
                child: GestureDetector(
                  onScaleUpdate: (details) {
                    setState(() {
                      _textOffset += details.focalPointDelta;
                      _textScale = (_textScale * details.scale).clamp(0.5, 3.0);
                    });
                  },
                  child: Transform.scale(
                    scale: _textScale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _overlayText,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 22,
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
                  ),
                ),
              ),
            for (int i = 0; i < _stickers.length; i++)
              Positioned(
                left: _stickers[i]['offset'].dx,
                top: _stickers[i]['offset'].dy,
                child: GestureDetector(
                  onScaleUpdate: (details) {
                    setState(() {
                      _stickers[i]['offset'] += details.focalPointDelta;
                      _stickers[i]['scale'] =
                          (_stickers[i]['scale'] * details.scale)
                              .clamp(0.5, 4.0);
                    });
                  },
                  onLongPress: () {
                    setState(() {
                      _stickers.removeAt(i);
                    });
                  },
                  child: Transform.scale(
                    scale: _stickers[i]['scale'],
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        _stickers[i]['content'],
                        style: TextStyle(
                          fontSize: _stickers[i]['type'] == 'emoji' ? 36 : 20,
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
                  ),
                ),
              ),
            Positioned(
              bottom: 30,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _colors
                          .map((color) => GestureDetector(
                                onTap: () => setState(() => _textColor = color),
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: textColor, width: 2),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return TextField(
                        controller: _textController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: isMm
                              ? "စာသား အနည်းငယ်ရေးရန်..."
                              : "Write a short caption...",
                          hintStyle:
                              TextStyle(color: textColor.withOpacity(0.6)),
                          filled: true,
                          fillColor: Colors.black54,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.blueAccent, size: 28),
                            onPressed: () {
                              setState(() {
                                _overlayText = _textController.text.trim();
                              });
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _overlayText = value;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeartClipper extends CustomClipper<Path> {
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
