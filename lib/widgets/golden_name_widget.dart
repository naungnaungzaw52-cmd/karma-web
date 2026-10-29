import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:karma/utilis/theme_provider.dart';

class GoldenNameWidget extends StatelessWidget {
  final String name;
  final String? role;
  final double fontSize;
  final Color? textColor;
  final bool
      isWhiteBackground; // 👈 Post Card ထဲမှာဆိုရင် true လို့ ပို့ပေးရပါမယ်

  const GoldenNameWidget({
    super.key,
    required this.name,
    this.role,
    this.fontSize = 18,
    this.textColor,
    this.isWhiteBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // role ကို အသေးပြောင်းပြီး တိုက်စစ်ပါ
    final String normalizedRole = (role ?? '').trim().toLowerCase();
    bool isGolden = (normalizedRole == 'admin' ||
        normalizedRole == 'team_karma' ||
        normalizedRole == 'vip' ||
        normalizedRole == 'gold_user');

    Color calculatedColor;
    if (isGolden) {
      calculatedColor = Colors.amber;
    } else if (textColor != null) {
      calculatedColor = textColor!;
    } else if (isWhiteBackground) {
      calculatedColor = Colors
          .black87; // 👈 ဤနေရာတွင် Colors.white အစား Colors.black87 ဟု ပြင်ပါ (နောက်ခံအဖြူပေါ်တွင် အမဲရောင်ပေါ်စေရန်)
    } else {
      // နောက်ခံမည်း (Profile Page ကဲ့သို့သော နေရာများ) အတွက်
      calculatedColor = (themeProvider.currentTheme == 'Default')
          ? Colors.black87
          : themeProvider.getTextColor();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: calculatedColor,
          ),
        ),
        if (isGolden) ...[
          const SizedBox(width: 6),
          const Icon(Icons.verified, color: Colors.amber, size: 20),
        ],
      ],
    );
  }
}
