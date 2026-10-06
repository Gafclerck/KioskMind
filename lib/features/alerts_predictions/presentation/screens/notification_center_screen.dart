import 'package:flutter/material.dart';
import 'package:kiosk_mind/core/theme/app_colors.dart';
import 'package:kiosk_mind/features/alerts_predictions/presentation/widgets/card_notification.dart';

class ScreenNotificationCenter extends StatelessWidget {
  const ScreenNotificationCenter({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // centerTitle: true,
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: AppColors.lightSurface,
            radius: 18,
            child: const Icon(Icons.arrow_back_ios, size: 15),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Centre de notifications",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () async {},
            child: Text(
              "Tout lire",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Column(
          spacing: 15,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "AUJOURD'HUI",
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            CardNotification(
              message:
                  "Riz Royal 5kg : Stock inférieur au seuil d’alerte critique.",
              time: "il y a 1 h",
              notificationTitle: "Alerte critique",
            ),
            CardNotification(
              message:
                  "Riz Royal 5kg : Stock inférieur au seuil d’alerte critique.",
              time: "il y a 1 h",
              notificationTitle: "Alerte critique",
            ),
            CardNotification(
              message:
                  "Riz Royal 5kg : Stock inférieur au seuil d’alerte critique.",
              time: "il y a 1 h",
              notificationTitle: "Alerte critique",
            ),
            CardNotification(
              message:
                  "Riz Royal 5kg : Stock inférieur au seuil d’alerte critique.",
              time: "il y a 1 h",
              notificationTitle: "Alerte critique",
            ),
          ],
        ),
      ),
    );
  }
}
