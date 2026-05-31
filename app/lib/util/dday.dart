/// 만난 날 2024-05-16을 1일차로 하는 D+ 카운터.
final DateTime kStartDate = DateTime(2024, 5, 16);

int dPlus([DateTime? now]) {
  final today = now ?? DateTime.now();
  final a = DateTime(kStartDate.year, kStartDate.month, kStartDate.day);
  final b = DateTime(today.year, today.month, today.day);
  return b.difference(a).inDays + 1; // 만난 날 = 1일
}

String dPlusLabel([DateTime? now]) => 'D+${dPlus(now)}';
