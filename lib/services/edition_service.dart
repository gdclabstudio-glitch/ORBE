import '../models/edition.dart';

class EditionService {
  const EditionService();

  List<Edition> generateHistoricalEditions({
    int? currentYear,
    int startYear = 2018,
  }) {
    final anchorYear = currentYear ?? DateTime.now().year;
    final years = <int>[];

    for (var year = anchorYear; year >= startYear; year--) {
      years.add(year);
    }

    return years.map((year) => Edition.fromYear(year)).toList();
  }
}
