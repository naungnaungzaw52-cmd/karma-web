import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:karma/main.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'package:karma/widgets/banner_ad_widget.dart';

class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final bool isDark = themeProvider.currentTheme != 'Default';
    final Color textColor = themeProvider.getTextColor();

    final Color cardColor = isDark ? Colors.grey.shade900 : Colors.white;

    return Container(
      decoration: themeProvider.getBackgroundDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          title: Text(
            'Karma Rewards',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // 🌳 KARMA TREE
                    _buildKarmaTree(),

                    const SizedBox(height: 25),

                    // 🌟 COMING SOON
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFB74D),
                            Color(0xFFFF9800),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'COMING SOON',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🌍 TITLE
                    ValueListenableBuilder<bool>(
                      valueListenable: isMyanmarNotifier,
                      builder: (context, isMm, child) {
                        return Column(
                          children: [
                            Text(
                              isMm
                                  ? 'Karma Rewards မကြာမီလာပါတော့မယ်!'
                                  : 'Karma Rewards is Coming!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isMm
                                  ? 'သင့်ရဲ့ Karma ခရီးစဉ်မှာ ပါဝင်ရင်း '
                                      'K-Points တွေ စုဆောင်းနိုင်မယ့် '
                                      'အခွင့်အရေးအသစ်တွေ မကြာခင် ရောက်ရှိလာတော့မှာပါ။'
                                  : 'A new way to collect K-Points and '
                                      'enjoy exciting rewards is coming '
                                      'soon to Karma.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // 🎁 UPCOMING BENEFITS
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Text(
                            isMm
                                ? 'နောင်လာမယ့် အခွင့်အရေးများ'
                                : 'What’s Coming Next',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 15),

                    _buildFeatureCard(
                      context: context,
                      cardColor: cardColor,
                      textColor: textColor,
                      icon: Icons.monetization_on_rounded,
                      iconColor: Colors.amber,
                      mmTitle: 'K-Points စုဆောင်းခြင်း',
                      enTitle: 'Collect K-Points',
                      mmDescription:
                          'Activity များမှတစ်ဆင့် K-Points များ စုဆောင်းနိုင်မည်။',
                      enDescription:
                          'Collect K-Points through activities on Karma.',
                    ),

                    _buildFeatureCard(
                      context: context,
                      cardColor: cardColor,
                      textColor: textColor,
                      icon: Icons.card_giftcard_rounded,
                      iconColor: Colors.pinkAccent,
                      mmTitle: 'အထူးလက်ဆောင်များ',
                      enTitle: 'Special Gifts',
                      mmDescription:
                          'စုဆောင်းထားသော Points များဖြင့် လက်ဆောင်များ ရယူနိုင်မည်။',
                      enDescription:
                          'Unlock exciting gifts with your collected points.',
                    ),

                    _buildFeatureCard(
                      context: context,
                      cardColor: cardColor,
                      textColor: textColor,
                      icon: Icons.workspace_premium_rounded,
                      iconColor: Colors.orange,
                      mmTitle: 'အထူးအခွင့်အရေးများ',
                      enTitle: 'Special Benefits',
                      mmDescription:
                          'Karma အသုံးပြုသူများအတွက် အကျိုးခံစားခွင့်အသစ်များ။',
                      enDescription:
                          'Enjoy exclusive benefits and new opportunities.',
                    ),

                    const SizedBox(height: 25),

                    // 💚 FOOTER MESSAGE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.2),
                        ),
                      ),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isMyanmarNotifier,
                        builder: (context, isMm, child) {
                          return Column(
                            children: [
                              const Icon(
                                Icons.eco_rounded,
                                color: Colors.green,
                                size: 30,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isMm
                                    ? 'အတူတကွ ဖန်တီးပါ။ အတူတကွ တိုးတက်ပါ။'
                                    : 'Grow Together. Benefit Together.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                isMm
                                    ? 'Karma နဲ့အတူ အနာဂတ်အခွင့်အရေးသစ်တွေကို '
                                        'စောင့်မျှော်လိုက်ပါ။'
                                    : 'Stay connected with Karma for '
                                        'exciting upcoming rewards.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor.withOpacity(0.65),
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // 📢 BANNER AD
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  // 🌳 KARMA TREE ILLUSTRATION
  Widget _buildKarmaTree() {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.08),
            Colors.teal.withOpacity(0.03),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🌟 Background circles
          Positioned(
            top: 25,
            left: 35,
            child: _buildDecorationCircle(12),
          ),

          Positioned(
            top: 55,
            right: 40,
            child: _buildDecorationCircle(8),
          ),

          Positioned(
            bottom: 55,
            left: 65,
            child: _buildDecorationCircle(9),
          ),

          // 🌳 Tree leaves
          Positioned(
            top: 35,
            child: Container(
              width: 165,
              height: 165,
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 75,
            left: 85,
            child: _leaf(65, Colors.green.shade400),
          ),

          Positioned(
            top: 80,
            right: 85,
            child: _leaf(65, Colors.green.shade700),
          ),

          Positioned(
            top: 25,
            child: _leaf(75, Colors.lightGreen.shade400),
          ),

          // 🌲 Tree trunk
          Positioned(
            bottom: 35,
            child: Container(
              width: 38,
              height: 95,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.brown.shade400,
                    Colors.brown.shade800,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // 🪙 K Coins
          const Positioned(
            top: 65,
            left: 75,
            child: _KCoin(size: 42),
          ),

          const Positioned(
            top: 105,
            right: 75,
            child: _KCoin(size: 38),
          ),

          const Positioned(
            top: 15,
            child: _KCoin(size: 45),
          ),

          const Positioned(
            top: 145,
            left: 115,
            child: _KCoin(size: 35),
          ),

          const Positioned(
            top: 145,
            right: 115,
            child: _KCoin(size: 35),
          ),

          // 🌱 Ground
          Positioned(
            bottom: 25,
            child: Container(
              width: 190,
              height: 15,
              decoration: BoxDecoration(
                color: Colors.green.shade300,
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),

          // ✨ Small stars
          const Positioned(
            top: 45,
            left: 45,
            child: Icon(
              Icons.star,
              color: Colors.amber,
              size: 18,
            ),
          ),

          const Positioned(
            top: 100,
            right: 35,
            child: Icon(
              Icons.auto_awesome,
              color: Colors.orangeAccent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaf(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildDecorationCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.amber,
        shape: BoxShape.circle,
      ),
    );
  }

  // 🎁 FEATURE CARD
  Widget _buildFeatureCard({
    required BuildContext context,
    required Color cardColor,
    required Color textColor,
    required IconData icon,
    required Color iconColor,
    required String mmTitle,
    required String enTitle,
    required String mmDescription,
    required String enDescription,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: isMyanmarNotifier,
              builder: (context, isMm, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMm ? mmTitle : enTitle,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isMm ? mmDescription : enDescription,
                      style: TextStyle(
                        color: textColor.withOpacity(0.65),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Icon(
            Icons.lock_clock_rounded,
            color: textColor.withOpacity(0.35),
            size: 20,
          ),
        ],
      ),
    );
  }
}

// 🪙 K-POINT COIN
class _KCoin extends StatelessWidget {
  final double size;

  const _KCoin({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFFB300),
            Color(0xFFFF8F00),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFFF3CD),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'K',
        style: TextStyle(
          color: Colors.brown.shade800,
          fontSize: size * 0.48,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
