import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.photoUrl,
    this.initials = '?',
    this.radius = 28,
    this.onTap,
  });

  final String? photoUrl;
  final String initials;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String? url = photoUrl;

    final Widget avatar = url != null && url.isNotEmpty
        ? CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(url),
            onBackgroundImageError: (_, _) {},
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              initials,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.72,
              ),
            ),
          );

    if (onTap == null) {
      return avatar;
    }
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: avatar,
    );
  }
}
