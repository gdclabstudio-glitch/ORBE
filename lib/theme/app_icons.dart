import 'package:flutter/material.dart';

import 'app_theme.dart';

class AppIcons {
  const AppIcons._();

  static const memories = Icons.photo_library_outlined;
  static const chat = Icons.chat_bubble_outline;
  static const foliaos = Icons.groups_outlined;
  static const settings = Icons.settings_outlined;
  static const notifications = Icons.notifications_none_outlined;
  static const profile = Icons.person_outline;
  static const badge = Icons.card_membership_outlined;
  static const moderation = Icons.shield_outlined;
  static const menu = Icons.menu;
  static const camera = Icons.camera_alt_outlined;
  static const celebration = Icons.celebration_outlined;

  static Icon themed(IconData icon, {Color? color, double? size}) {
    return Icon(icon, color: color ?? AppTheme.primary, size: size);
  }
}
