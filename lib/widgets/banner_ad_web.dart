// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

class WebBannerAdWidget extends StatefulWidget {
  const WebBannerAdWidget({super.key});

  @override
  State<WebBannerAdWidget> createState() => _WebBannerAdWidgetState();
}

class _WebBannerAdWidgetState extends State<WebBannerAdWidget> {
  static bool _registered = false;

  @override
  void initState() {
    super.initState();

    if (!_registered) {
      ui.platformViewRegistry.registerViewFactory(
        'adsterra-banner-320x50',
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = '/ads/banner.html'
            ..style.border = '0'
            ..style.width = '320px'
            ..style.height = '50px'
            ..setAttribute('scrolling', 'no')
            ..setAttribute('title', 'Advertisement');

          return iframe;
        },
      );

      _registered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      child: const SizedBox(
        width: 320,
        height: 50,
        child: HtmlElementView(
          viewType: 'adsterra-banner-320x50',
        ),
      ),
    );
  }
}
