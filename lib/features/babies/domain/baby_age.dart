enum BabyAgeUnit { days, weeks, months, years }

/// Edad calculada a partir de la fecha de nacimiento (no se guarda).
/// Convención de pediatría: días hasta las 2 semanas, semanas hasta los 3
/// meses, meses hasta los 2 años y años a partir de ahí.
class BabyAge {
  const BabyAge({required this.totalDays, required this.totalMonths});

  factory BabyAge.between(DateTime birth, DateTime today) {
    final b = DateTime.utc(birth.year, birth.month, birth.day);
    final t = DateTime.utc(today.year, today.month, today.day);
    if (t.isBefore(b)) return const BabyAge(totalDays: 0, totalMonths: 0);
    var months = (t.year - b.year) * 12 + t.month - b.month;
    if (t.day < b.day) months -= 1;
    return BabyAge(
      totalDays: t.difference(b).inDays,
      totalMonths: months < 0 ? 0 : months,
    );
  }

  final int totalDays;
  final int totalMonths;

  BabyAgeUnit get unit {
    if (totalMonths >= 24) return BabyAgeUnit.years;
    if (totalMonths >= 3) return BabyAgeUnit.months;
    if (totalDays >= 14) return BabyAgeUnit.weeks;
    return BabyAgeUnit.days;
  }

  int get value => switch (unit) {
        BabyAgeUnit.years => totalMonths ~/ 12,
        BabyAgeUnit.months => totalMonths,
        BabyAgeUnit.weeks => totalDays ~/ 7,
        BabyAgeUnit.days => totalDays,
      };
}
