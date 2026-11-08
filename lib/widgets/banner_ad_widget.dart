// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart'; // 🌟 kIsWeb အတွက် လိုအပ်သည်
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';
import 'banner_ad_web_stub.dart' if (dart.library.html) 'banner_ad_web.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  final String _adUnitId = 'ca-app-pub-8755843731256088/5992414426';

  @override
  void initState() {
    super.initState();
    // 🌟 Web ဖြစ်နေပါက AdMob ကို လုံးဝ Load မလုပ်ပါ (Error တက်ခြင်းမှ ကာကွယ်ရန်)
    if (!kIsWeb) {
      _loadAd();
    }
  }

  void _loadAd() {
    if (kIsWeb) return; // Web ဆိုလျှင် ကျော်မည်

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          print('Ad loaded successfully.');
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          print('Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // WEB: Adsterra Banner
    if (kIsWeb) {
      return const WebBannerAdWidget();
    }
    // 🌟 Web ဖြစ်နေပါက Ad Widget အစား ဘာမှမပြရန် (SizedBox.shrink) ပြန်ပေးမည်
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    final themeProvider = Provider.of<ThemeProvider>(context);
    bool isDark = (themeProvider.currentTheme != 'Default');

    if (_isAdLoaded && _bannerAd != null) {
      return Transform.translate(
        offset: const Offset(0, 0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.15)
                : Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
          ),
        ),
      );
    }
    return const SizedBox(height: 0);
  }
}
