import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart'; // Provider ကို import လုပ်ပါ
import 'package:karma/pages/other_profile_page.dart';
import 'package:karma/widgets/golden_name_widget.dart';
import 'package:karma/utilis/theme_provider.dart'; // ThemeProvider ကို import လုပ်ပါ

class UserListPage extends StatelessWidget {
  final String title;
  final String userId;
  final bool isFollowers;

  const UserListPage(
      {super.key,
      required this.title,
      required this.userId,
      required this.isFollowers});

  @override
  Widget build(BuildContext context) {
    // ThemeProvider ကို ခေါ်သုံးခြင်း
    final themeProvider = Provider.of<ThemeProvider>(context);
    Color textColor = themeProvider.getTextColor();

    return Container(
      // Theme အလိုက် Background ပြောင်းလဲခြင်း
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor:
            Colors.transparent, // Background အကြည်ထားမှ Decoration ပေါ်မည်
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: Text(
            title,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ),
        body: isFollowers
            ? StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('following', arrayContains: userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var docs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var userData = docs[index].data() as Map<String, dynamic>;
                      String uid = docs[index].id;
                      return ListTile(
                        leading: CircleAvatar(
                            backgroundImage: NetworkImage(
                                userData['profileImageUrl'] ?? "")),
                        title: GoldenNameWidget(
                          name: userData['displayName'] ?? "အသုံးပြုသူ",
                          role: userData['role'] ?? 'member',
                          fontSize: 16,
                        ),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => OtherProfilePage(
                                      userId: uid,
                                      userName: userData['displayName'] ??
                                          "အသုံးပြုသူ")));
                        },
                      );
                    },
                  );
                },
              )
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  List userIds = (snapshot.data!.data()
                          as Map<String, dynamic>)['following'] ??
                      [];

                  return ListView.builder(
                    itemCount: userIds.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userIds[index])
                            .get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) {
                            return const ListTile(title: Text("Loading..."));
                          }
                          var userData =
                              userSnap.data!.data() as Map<String, dynamic>;
                          String uid = userSnap.data!.id;
                          return ListTile(
                            leading: CircleAvatar(
                                backgroundImage: NetworkImage(
                                    userData['profileImageUrl'] ?? "")),
                            title: GoldenNameWidget(
                              name: userData['displayName'] ?? "အသုံးပြုသူ",
                              role: userData['role'] ?? 'member',
                              fontSize: 16,
                            ),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => OtherProfilePage(
                                          userId: uid,
                                          userName: userData['displayName'] ??
                                              "အသုံးပြုသူ")));
                            },
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
