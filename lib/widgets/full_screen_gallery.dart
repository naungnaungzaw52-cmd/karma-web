// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:karma/main.dart';
import 'package:path_provider/path_provider.dart';
import 'banner_ad_widget.dart'; // 🌟 Ad Banner Widget ကို import လုပ်ရန်[cite: 14]

class FullScreenGalleryScreen extends StatefulWidget {
  final List<String> mediaUrls;
  final int initialIndex;

  const FullScreenGalleryScreen({
    super.key,
    required this.mediaUrls,
    required this.initialIndex,
  });

  @override
  State<FullScreenGalleryScreen> createState() =>
      _FullScreenGalleryScreenState();
}

class _FullScreenGalleryScreenState extends State<FullScreenGalleryScreen> {
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

  // လက်ရှိပြနေသော ပုံကို ဖုန်းထဲသို့ Download ဆွဲရန်[cite: 14]
  Future<void> _downloadCurrentImage() async {
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
        final isMm = isMyanmarNotifier.value;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMm
                  ? 'ပုံကို Download ဆွဲပြီးပါပြီ: ${file.path}'
                  : 'Image downloaded successfully: ${file.path}',
            ),
          ),
        );
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      final isMm = isMyanmarNotifier.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'ပုံ Download လုပ်၍ မအောင်မြင်ပါ: $e'
                : 'Failed to download image: $e',
          ),
          backgroundColor: Colors.red,
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
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
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
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: isMyanmarNotifier,
                          builder: (context, isMm, child) {
                            return Text(
                              isMm
                                  ? "ပုံကို ဖတ်၍မရပါ။"
                                  : "Failed to load image.",
                              style: const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 🌟 အောက်ခြေဆုံးတွင် Banner Ad ထည့်သွင်းခြင်း[cite: 14]
          const BannerAdWidget(),
        ],
      ),
    );
  }
}
