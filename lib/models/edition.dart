class Edition {
  final int year;
  final String label;
  final String imageUrl;

  const Edition({
    required this.year,
    required this.label,
    required this.imageUrl,
  });

  factory Edition.fromYear(int year, {String? label, String? imageUrl}) {
    return Edition(
      year: year,
      label: label ?? _defaultLabelForYear(year),
      imageUrl: imageUrl ?? 'assets/images/$year.png',
    );
  }

  static String _defaultLabelForYear(int year) {
    final currentYear = DateTime.now().year;

    if (year == currentYear) {
      return 'Edição Atual';
    }
    if (year == currentYear - 1) {
      return 'Edição Lendária';
    }
    return 'Histórico';
  }
}
