// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

class WebNativeAdWidget extends StatefulWidget {
  const WebNativeAdWidget({super.key});

  @override
  State<WebNativeAdWidget> createState() => _WebNativeAdWidgetState();
}

class _WebNativeAdWidgetState extends State<WebNativeAdWidget> {
  static bool _registered = false;

  @override
  void initState() {
    super.initState();

    if (!_registered) {
      ui.platformViewRegistry.registerViewFactory(
        'karma-native-ad',
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = '/ads/native.html'
            ..style.border = '0'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.setProperty('touch-action', 'pan-y')
            ..setAttribute('scrolling', 'no')
            ..setAttribute('title', 'Sponsored Advertisement');

          return iframe;
        },
      );

      _registered = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: HtmlElementView(
        viewType: 'karma-native-ad',
      ),
    );
  }
}
