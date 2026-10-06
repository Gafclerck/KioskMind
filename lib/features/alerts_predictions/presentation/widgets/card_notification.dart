import 'package:flutter/material.dart';
import 'package:kiosk_mind/core/theme/app_colors.dart';

class CardNotification extends StatelessWidget {
  final String message;
  final String notificationTitle;
  final String time;

  /// Indicateur « non lu » (point rouge). true par défaut pour
  /// préserver le rendu existant.
  final bool isUnread;

  const CardNotification({
    super.key,
    required this.message,
    required this.time,
    required this.notificationTitle,
    this.isUnread = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        border: Border.all(
          color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    spacing: 10,
                    children: [
                      CircleAvatar(radius: 5, backgroundColor: AppColors.error),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text(
                          notificationTitle,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Text(
                message,
                style: TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
