import 'package:flutter/material.dart';
import 'package:kiosk_mind/core/theme/app_colors.dart';

enum StatutAlert { urgent, prevision, conseil }

class CardAlert extends StatelessWidget {
  final StatutAlert statutAlert;
  final String productNameWithStock;
  final String alertMessage;

  /// Action du bouton (« Commander » / « Planifier »).
  /// null => bouton désactivé (pas d'action connue).
  final VoidCallback? onPressed;

  const CardAlert({
    super.key,
    required this.statutAlert,
    required this.productNameWithStock,
    required this.alertMessage,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    Container test(StatutAlert statutAlert) {
      switch (statutAlert) {
        case StatutAlert.urgent:
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.error),
              color: AppColors.errorDark.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            width: 359,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: AppColors.lightBackground,
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.errorLight,
                            ),
                          ),
                          Text(
                            productNameWithStock,
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      Container(
                        height: 25,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          border: Border.all(color: AppColors.error),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: const Text(
                            "URGENT",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: AppColors.errorLight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(alertMessage, style: TextStyle(fontSize: 13)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.lightBackground,
                        ),
                        onPressed: onPressed,
                        child: Row(
                          children: [
                            const Text("Commander"),
                            Icon(Icons.arrow_right_alt),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        case StatutAlert.prevision:
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.errorMid),
              color: AppColors.errorMid.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            width: 359,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: AppColors.lightBackground,
                            child: Icon(
                              Icons.trending_up_rounded,
                              color: AppColors.errorMid,
                            ),
                          ),
                          Text(
                            productNameWithStock,
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      Container(
                        height: 25,
                        width: 75,
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          border: Border.all(color: AppColors.errorMid),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: const Text(
                            "PREVISION",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: AppColors.errorMid,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(alertMessage, style: TextStyle(fontSize: 13)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.lightBackground,
                        ),
                        onPressed: onPressed,
                        child: Row(
                          children: [
                            Text("Commander"),
                            Icon(Icons.arrow_right_alt),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );

        case StatutAlert.conseil:
          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryDark),
              color: AppColors.primaryDark.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            width: 359,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: AppColors.lightBackground,
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Text(
                            productNameWithStock,
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      Container(
                        height: 25,
                        width: 60,
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          border: Border.all(color: AppColors.primaryDark),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            "CONSEIL",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(alertMessage, style: TextStyle(fontSize: 13)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.lightBackground,
                        ),
                        onPressed: onPressed,
                        child: Row(
                          children: [
                            Text("Planifier"),
                            Icon(Icons.arrow_right_alt),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
      }
    }

    return test(statutAlert);
  }
}
