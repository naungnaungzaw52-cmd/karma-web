import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'native_ad_web_stub.dart' if (dart.library.html) 'native_ad_web.dart';

class NativeAdWidget extends StatelessWidget {
  const NativeAdWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Sponsored',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          AspectRatio(
            aspectRatio:
                MediaQuery.of(context).size.width < 400 ? 1 / 1 : 4 / 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const WebNativeAdWidget(),
            ),
          ),
        ],
      ),
    );
  }
}
