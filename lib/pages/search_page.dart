// ignore_for_file: avoid_print

import 'dart:ui'; // 🌟 BackdropFilter အတွက် လိုအပ်သည်
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart'; // 🌟 url_launcher ထည့်သွင်းခြင်း
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:karma/main.dart';
import 'package:karma/pages/other_profile_page.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:karma/widgets/post_detail_screen.dart';
import 'package:karma/widgets/banner_ad_widget.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery; // 🌟 ပြင်ပမှ Hashtag နှိပ်၍ ရောက်လာပါက လက်ခံရန်

  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late TextEditingController _searchController;
  String _searchQuery = "";

  // 🌟 Wikipedia ရလဒ်များကို Cache လုပ်ထားရန်နှင့် တည်ငြိမ်စေရန်
  Future<List<dynamic>>? _wikiFuture;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery ?? "";
    _searchController = TextEditingController(text: _searchQuery);
    if (_searchQuery.trim().isNotEmpty) {
      _wikiFuture = _fetchWikipediaResults(_searchQuery);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // 🌟 Wikipedia API မှ Data လှမ်းဆွဲမည့် Function (Error Handling ပိုမိုကောင်းမွန်စေရန်)
  Future<List<dynamic>> _fetchWikipediaResults(String query) async {
    if (query.trim().isEmpty) return [];
    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=$encodedQuery&format=json');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['query']?['search'] ?? [];
      }
    } catch (e) {
      print("Wiki search error: $e");
    }
    return [];
  }

  // 🌟 Wikipedia Link ကို Browser ဖြင့် ဖွင့်ပေးမည့် Function
  Future<void> _launchWikiUrl(int pageId) async {
    final Uri url = Uri.parse('https://en.wikipedia.org/?curid=$pageId');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDarkTheme = themeProvider.currentTheme != 'Default';

    // Theme အလိုက် အရောင်များ သတ်မှတ်ခြင်း
    Color textColor = themeProvider.getTextColor();
    Color subTextColor = isDarkTheme ? Colors.grey[400]! : Colors.grey[600]!;

    // Blur box background အရောင်များ
    Color boxBgColor = isDarkTheme
        ? Colors.black.withOpacity(0.3)
        : Colors.white.withOpacity(0.4);

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
                isMm ? "ရှာဖွေရန်" : "Search",
                style: TextStyle(color: textColor),
              );
            },
          ),
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Column(
          children: [
            // 🌟 Search TextField ကို Blur Effect ထည့်ခြင်း
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isMyanmarNotifier,
                    builder: (context, isMm, child) {
                      return TextField(
                        controller: _searchController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: isMm
                              ? "နာမည်၊ #tag သို့မဟုတ် Wiki ရှာရန်..."
                              : "Search users, posts, or Wiki...",
                          hintStyle:
                              TextStyle(color: textColor.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.search, color: textColor),
                          filled: true,
                          fillColor: boxBgColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.trim();
                            // Query ပြောင်းလဲတိုင်း Wikipedia Future ကို အသစ်ပြန်ခေါ်ရန် သတ်မှတ်ခြင်း
                            if (_searchQuery.isNotEmpty) {
                              _wikiFuture =
                                  _fetchWikipediaResults(_searchQuery);
                            } else {
                              _wikiFuture = Future.value([]);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // 🌟 Users နှင့် Posts များကို Firestore မှ တပြိုင်နက် ဆွဲထုတ်ရန် StreamBuilder များ သုံးခြင်း
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .snapshots(),
                    builder: (context, postSnapshot) {
                      if (!postSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Users များကို စစ်ထုတ်ခြင်း
                      var allUsers = userSnapshot.data!.docs;
                      var filteredUsers = allUsers.where((doc) {
                        if (_searchQuery.isEmpty) return true;
                        var data = doc.data() as Map<String, dynamic>;
                        String name = (data['displayName'] ?? '').toLowerCase();
                        return name.contains(_searchQuery.toLowerCase());
                      }).toList();

                      // Posts များကို စစ်ထုတ်ခြင်း
                      var allPosts = postSnapshot.data!.docs;
                      var filteredPosts = allPosts.where((doc) {
                        if (_searchQuery.isEmpty) return true;
                        var data = doc.data() as Map<String, dynamic>;
                        String queryLower = _searchQuery.toLowerCase();
                        List<dynamic> hashtags = data['hashtags'] ?? [];
                        String text = (data['text'] ?? '').toLowerCase();

                        if (queryLower.startsWith('#')) {
                          return hashtags.any((tag) => tag
                              .toString()
                              .trim()
                              .toLowerCase()
                              .contains(queryLower));
                        } else {
                          bool matchText = text.contains(queryLower);
                          bool matchTag = hashtags.any((tag) => tag
                              .toString()
                              .toLowerCase()
                              .contains(queryLower));
                          return matchText || matchTag;
                        }
                      }).toList();

                      bool hasSearch = _searchQuery.isNotEmpty;

                      return ListView(
                        padding: const EdgeInsets.only(bottom: 20),
                        children: [
                          // 1. Users Section (အသုံးပြုသူများ တွေ့ရှိပါက)
                          if (filteredUsers.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                "Users",
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                            ...filteredUsers.map((user) {
                              var userData =
                                  user.data() as Map<String, dynamic>;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      color: boxBgColor,
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.grey[300],
                                          backgroundImage: userData[
                                                      'profileImageUrl'] !=
                                                  null
                                              ? NetworkImage(
                                                  userData['profileImageUrl'])
                                              : null,
                                          child: userData['profileImageUrl'] ==
                                                  null
                                              ? const Icon(Icons.person)
                                              : null,
                                        ),
                                        title: GoldenNameWidget(
                                          name:
                                              userData['displayName'] ?? "User",
                                          role: userData['role'] ?? 'member',
                                          fontSize: 16,
                                          isWhiteBackground: !isDarkTheme,
                                        ),
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                OtherProfilePage(
                                              userId: user.id,
                                              userName:
                                                  userData['displayName'] ??
                                                      "User",
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                          ],

                          // 2. Posts Section (ပို့စ်များ တွေ့ရှိပါက)
                          if (filteredPosts.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                "Posts",
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                            ...filteredPosts.map((post) {
                              var postData =
                                  post.data() as Map<String, dynamic>;
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      color: boxBgColor,
                                      child: ListTile(
                                        title: FutureBuilder<DocumentSnapshot>(
                                          future: FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(postData['uid'])
                                              .get(),
                                          builder: (context, userSnapshot) {
                                            String role = 'member';
                                            if (userSnapshot.hasData &&
                                                userSnapshot.data!.exists) {
                                              var uData =
                                                  userSnapshot.data!.data()
                                                      as Map<String, dynamic>;
                                              role = uData['role'] ?? 'member';
                                            }

                                            return GoldenNameWidget(
                                              name: postData['userName'] ??
                                                  "User",
                                              role: role,
                                              fontSize: 16,
                                              isWhiteBackground: !isDarkTheme,
                                            );
                                          },
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            postData['text'] ?? "",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                TextStyle(color: subTextColor),
                                          ),
                                        ),
                                        onTap: () =>
                                            _showPostDetail(context, post),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                          ],

                          // 3. Wikipedia Results Section (State ထိန်းထားသော _wikiFuture ကို အသုံးပြုခြင်း)
                          if (hasSearch && _wikiFuture != null) ...[
                            FutureBuilder<List<dynamic>>(
                              future: _wikiFuture,
                              builder: (context, wikiSnapshot) {
                                if (wikiSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                if (!wikiSnapshot.hasData ||
                                    wikiSnapshot.data!.isEmpty) {
                                  if (filteredUsers.isEmpty &&
                                      filteredPosts.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(30.0),
                                        child: Text(
                                          "No results found.",
                                          style: TextStyle(
                                              color: textColor, fontSize: 16),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }

                                var wikiResults = wikiSnapshot.data!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 12.0),
                                      child: Text(
                                        "Wikipedia Results",
                                        style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ),
                                    ...wikiResults.map((wiki) => Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(
                                                  sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                color: boxBgColor,
                                                child: ListTile(
                                                  leading: const Icon(
                                                      Icons.public,
                                                      color: Colors.amber),
                                                  title: Text(
                                                    wiki['title'] ?? '',
                                                    style: TextStyle(
                                                        color: textColor,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  subtitle: Text(
                                                    (wiki['snippet'] ?? '')
                                                        .replaceAll(
                                                            RegExp(('<[^>]*>')),
                                                            ''),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                        color: subTextColor),
                                                  ),
                                                  onTap: () {
                                                    int pageId =
                                                        wiki['pageid'] ?? 0;
                                                    if (pageId != 0) {
                                                      _launchWikiUrl(pageId);
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        )),
                                  ],
                                );
                              },
                            ),
                          ] else if (filteredUsers.isEmpty &&
                              filteredPosts.isEmpty) ...[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Text(
                                  "Type something to search users, posts, or Wikipedia...",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: subTextColor, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // 🌟 အောက်ခြေဆုံးတွင် Banner Ad ထည့်သွင်းခြင်း
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}
