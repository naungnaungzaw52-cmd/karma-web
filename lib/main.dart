// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart'; // kIsWeb အတွက် လိုအပ်သည်
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:karma/widgets/splash_screen_widget.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Background Notification ကို လက်ခံမည့် Function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Background Firebase init error: $e");
  }
  print("Handling a background message: ${message.messageId}");

  if (message.data['type'] == 'call') {
    String callId = message.data['callId'] ?? '';
    String callerName = message.data['callerName'] ?? 'အမည်မသိ';
    String callerAvatar = message.data['callerAvatar'] ??
        'https://cdn-icons-png.flaticon.com/512/3135/3135768.png';

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

    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  } else if (message.data['type'] == 'end_call') {
    print("🔥 Background end_call received, dismissing CallKit...");
    await FlutterCallkitIncoming.endAllCalls();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Missed call notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Missed call',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'call_back_action',
          'Call back',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    String callerName = message.data['callerName'] ?? 'အမည်မသိ';

    await flutterLocalNotificationsPlugin.show(
      888,
      'karma • Missed call',
      callerName,
      platformChannelSpecifics,
      payload: message.data['callId'],
    );
  }
}

Future<void> _launchPrivacyPolicy() async {
  final Uri url = Uri.parse(
      'https://naungnaungzaw52-cmd.github.io/karma-policies/privacy.html');
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    throw Exception('Could not launch $url');
  }
}

ValueNotifier<bool> isMyanmarNotifier = ValueNotifier<bool>(true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Image Cache သတ်မှတ်ခြင်း
  PaintingBinding.instance.imageCache.maximumSize = 1000;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

  // SharedPreferences ဖြင့် ဘာသာစကား သိမ်းဆည်းမှုကို ဖတ်ခြင်း
  try {
    final prefs = await SharedPreferences.getInstance();
    bool savedIsMyanmar = prefs.getBool('is_myanmar_language') ?? true;
    isMyanmarNotifier.value = savedIsMyanmar;
  } catch (e) {
    print("Error loading language preference: $e");
  }

  // Firebase ကို လုံခြုံစွာ Initialize လုပ်ခြင်း
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Mobile (Android/iOS) အတွက်သာ App Check ကို အသက်သွင်းရန်
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.debug,
      );
    }
  } catch (e) {
    print("🔥 Firebase Initialization Error: $e");
  }

  // Notification Channel သတ်မှတ်ခြင်း (Mobile အတွက်)
  if (!kIsWeb) {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.data['type'] == 'end_call') {
          print("🔥 Foreground end_call received, dismissing CallKit...");
          FlutterCallkitIncoming.endAllCalls();
        }
      });
    } catch (e) {
      print("Notification setup error: $e");
    }
  }

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } catch (e) {
    print("Orientation error: $e");
  }

  // App ကို စတင် Run ခြင်း
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateUserStatus(true);
    if (!kIsWeb) {
      _requestNotificationPermission();
      _checkBatteryOptimization();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _updateUserStatus(true);
    } else {
      _updateUserStatus(false);
    }
  }

  void _updateUserStatus(bool isOnline) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'isOnline': isOnline,
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print("Update user status error: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted FCM permission');
      }

      bool isMyanmar = isMyanmarNotifier.value;
      await FlutterCallkitIncoming.requestNotificationPermission({
        "title":
            isMyanmar ? "ခွင့်ပြုချက် လိုအပ်ပါသည်။" : "Permission Required",
        "rationaleMessagePermission": isMyanmar
            ? "ဖုန်းဝင်လာပါက Screen ပေါ်တွင် အလွယ်တူ ပေါ်လာစေရန် ခွင့်ပြုချက် ပေးရန် လိုအပ်ပါသည်။"
            : "Permission is required to display incoming calls easily on the screen.",
        "postNotificationMessageRequired": isMyanmar
            ? "Settings ထဲသို့သွား၍ ခွင့်ပြုချက်ကို ဖွင့်ပေးပါ။"
            : "Please go to Settings and enable the permission."
      });
    } catch (e) {
      print("CallKit permission error: $e");
    }
  }

  Future<void> _checkBatteryOptimization() async {
    try {
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } catch (e) {
      print("Battery optimization permission error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Karma',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const AuthWrapper(),
    );
  }
}

// Login လား SplashScreen လား ခွဲပေးမည့် Widget
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const SplashScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 🌟 Google Sign-In Function
  Future<void> _signInWithGoogle() async {
    try {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      User? user = userCredential.user;
      if (user == null) return;

      await _saveUserToFirestore(user);
    } catch (e) {
      print("Google Sign In Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      String? fcmToken;
      if (!kIsWeb) {
        fcmToken = await FirebaseMessaging.instance.getToken();
      }
      String uid = user.uid;

      String fallbackName = user.email != null && user.email!.contains('@')
          ? user.email!.split('@')[0]
          : "အသုံးပြုသူ";

      String finalDisplayName =
          (user.displayName != null && user.displayName!.trim().isNotEmpty)
              ? user.displayName!
              : fallbackName;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': user.email ?? "",
        'displayName': finalDisplayName,
        'bio': "No bio yet",
        'profileImageUrl': user.photoURL ??
            "https://cdn-icons-png.flaticon.com/512/3135/3135768.png",
        'followingCount': 0,
        'fcmToken': fcmToken ?? "",
        'isOnline': true,
        'lastActive': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!kIsWeb) {
        await FirebaseMessaging.instance.subscribeToTopic('all_users');
      }
      print("Success: User data saved to Firestore!");
    } catch (e) {
      print("Save user to firestore error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: isMyanmarNotifier,
        builder: (context, isMyanmar, child) {
          return Stack(
            children: [
              Positioned.fill(
                  child: Image.asset('assets/clouds.png', fit: BoxFit.cover)),
              Positioned.fill(
                  child: Container(color: Colors.blue.withOpacity(0.3))),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cyclone,
                            size: 80, color: Colors.white),
                        const SizedBox(height: 30),
                        const Text("Karma",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 50),

                        // Google Sign In Button (သီးသန့်)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                            ),
                            icon: const Icon(Icons.login, color: Colors.blue),
                            onPressed: _signInWithGoogle,
                            label: Text(
                              isMyanmar
                                  ? "Google ဖြင့် ဝင်ရောက်မည်"
                                  : "Sign in with Google",
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text.rich(
                            TextSpan(
                              text: isMyanmar
                                  ? "ဝင်ရောက်ခြင်းဖြင့် ကျွန်ုပ်တို့၏ စည်းကမ်းချက်များနှင့် "
                                  : "By signing in, you agree to our ",
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                              children: [
                                WidgetSpan(
                                  child: GestureDetector(
                                    onTap: _launchPrivacyPolicy,
                                    child: Text(
                                      isMyanmar
                                          ? "ကိုယ်ရေးအချက်အလက်မူဝါဒ"
                                          : "Privacy Policy",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                TextSpan(
                                  text: isMyanmar ? " ကို သဘောတူပါသည်။" : ".",
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
