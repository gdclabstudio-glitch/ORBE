class UserBadge {
  final String id;
  final String title;
  final String description;
  final String icon; // asset name or emoji

  const UserBadge({
    required this.id,
    required this.title,
    required this.description,
    this.icon = '🏆',
  });
}
