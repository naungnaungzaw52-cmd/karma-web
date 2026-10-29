import 'dart:math';
import 'package:flutter/material.dart';
import 'package:karma/main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Animation အတွက် Controller
  late AnimationController _animationController;

  // သံဝေဂနှင့် Karma ဆိုင်ရာ စာသားများ
  final List<String> _quotes = [
    "What goes around, comes around.",
    "ကိုယ်ပြုသမျှ ကိုယ့်ထံပြန်လာမည်။",
    "Doing good brings inner peace.",
    "အကောင်းနှင့်အဆိုး ကိုယ့်လက်ထဲမှာ...",
    "Every action has an equal and opposite reaction.",
    "မကောင်းတာလုပ်ရင် မကောင်းတာပဲ ပြန်လာမယ်။",
    "Every action has an equal and opposite reaction in physics; every intent has a corresponding consequence in Kamma. You are the architect of your own reality.",
    "ရူပဗေဒမှာ လုပ်ရပ်တိုင်း တုံ့ပြန်မှုရှိသလို၊ ကံတရားမှာလည်း စေတနာတိုင်း အကျိုးပေးပါတယ်။ သင်ဟာ မိမိဘဝရဲ့ ပုံဖော်သူပါပဲ။",
    "Energy cannot be created or destroyed, it only changes form. Karma works the same—every deed leaves an eternal imprint on your reality.",
    "စွမ်းအင်ဆိုတာ ပျောက်ကွယ်မသွားဘဲ ပုံစံပြောင်းသွားသလိုပါပဲ။ ကံဆိုတာလည်း ပြုလုပ်လိုက်တဲ့ အလုပ်တိုင်းရဲ့ မလွဲမသွေ ဖြစ်လာမယ့် အကျိုးဆက်ပါပဲ။",
    "Science calls it the Law of Cause and Effect. The Buddha called it Kamma and Paticcasamuppada. Truth transcends labels.",
    "သိပ္ပံက အကြောင်းနဲ့အကျိုး နိယာမလို့ခေါ်တယ်။ မြတ်စွာဘုရားက ကံနဲ့ ပဋိစ္စသမုပ္ပါဒ်လို့ ဟောတယ်။ အမှန်တရားဆိုတာ ဘယ်တော့မှ မပြောင်းလဲပါဘူး။",
    "Just as a tiny seed dictates the tree, micro-intentions shape your macro-destiny. Physics and Dhamma speak the same language.",
    "မျိုးစေ့ငယ်လေးက သစ်ပင်ကြီးကို ဖန်တီးသလို၊ စိတ်ရဲ့ သေးငယ်တဲ့ စေတနာတွေက သင့်ရဲ့ ကံကြမ္မာကို ဖြစ်စေပါတယ်။ သိပ္ပံနဲ့ တရားတော်က လမ်းကြောင်းအတူတူပါပဲ။",
    "Action and Consequence: The universe balances itself through physical laws, and life balances itself through the law of Kamma.",
    "လုပ်ရပ်နဲ့ အကျိုးဆက်- စကြဝဠာက ရုပ်ပိုင်းဆိုင်ရာ နိယာမနဲ့ ချိန်ညှိသလို၊ ဘဝက ကံတရားရဲ့ သဘောတရားနဲ့ ချိန်ညှိနေပါတယ်။",
    "In physics, you reap what the forces plant. In life, you reap what your consciousness sows. This is the universal law of Kamma.",
    "ရူပဗေဒမှာ ဖြစ်ပေါ်လာတဲ့ စွမ်းအင်အတိုင်း ပြန်ခံစားရသလို၊ ဘဝမှာလည်း ကိုယ့်စိတ်နဲ့ ပြုလုပ်ခဲ့သမျှကို ပြန်လည်ခံစားရပါတယ်။ ဒါဟာ စကြဝဠာရဲ့ သဘာဝ ကံတရားပါပဲ။",
  ];

  late String _selectedQuote;

  @override
  void initState() {
    super.initState();

    // စာသား Random ရွေးမယ်
    _selectedQuote = _quotes[Random().nextInt(_quotes.length)];

    // ၃ စက္ကန့်စာ လည်ပတ်မယ့် Animation Controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(); // အဆက်မပြတ် လည်နေစေရန်

    // ၃ စက္ကန့်ပြည့်တာနဲ့ MainNavigation ကို ပို့မယ်
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigation()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose(); // Memory leak မဖြစ်အောင် ရှင်းလင်းခြင်း
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔻 Background Image (clouds.jpg)
          Positioned.fill(
            child: Image.asset('assets/clouds.png', fit: BoxFit.cover),
          ),
          // 🔻 အမှောင်ဖျော့ Overlay
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),
          // 🔻 အလယ်က Logo, Name, Animation နဲ့ Quote
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🔻 Cyclone Logo လည်နေတဲ့ Animation
                    RotationTransition(
                      turns: _animationController,
                      child: const Icon(
                        Icons
                            .cyclone, // မူလ Cyclone Icon လေးကို ပြန်သုံးထားပါတယ်
                        size: 90,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Karma",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 25),
                    // 🔻 သံဝေဂစာသား
                    Text(
                      _selectedQuote,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
