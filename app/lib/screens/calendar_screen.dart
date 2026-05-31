import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models/entry.dart';
import '../services/points_service.dart';
import '../services/room_service.dart';
import '../services/session_prefs.dart';
import '../util/users.dart';
import '../widgets/entry_image.dart';

/// 달력 탭: 월별 달력에서 그림이 있는 날짜에 점 표시, 날짜를 누르면 그 날의 그림들.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selected = DateTime.now();
  final _points = PointsService();

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('우리의 기록 📅')),
      body: !firebaseReady
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Firebase 연결 후 그동안 제출한 그림들이\n날짜별로 여기에 쌓입니다.', textAlign: TextAlign.center),
              ),
            )
          : StreamBuilder<List<Entry>>(
              stream: RoomService().watchAll(),
              builder: (context, snap) {
                final all = snap.data ?? [];
                final dates = all.map((e) => e.date).toSet(); // 그림 있는 날짜
                final selectedKey = _fmt(_selected);
                final dayEntries = all.where((e) => e.date == selectedKey).toList();
                // 둘 다 제출하기 전까지 상대 그림은 비공개(내 그림은 항상 보임).
                final myId = SessionPrefs.userId ?? '0421';
                final dayIds = dayEntries.map((e) => e.authorId).toSet();
                final bothDrew = dayIds.contains('0421') && dayIds.contains('0118');
                final visibleEntries = bothDrew ? dayEntries : dayEntries.where((e) => e.authorId == myId).toList();
                final partnerId = myId == '0421' ? '0118' : '0421';
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _points.watchInventory(),
                  builder: (context, invSnap) {
                    // 사용 완료한 상품 → 사용한 날짜별로 묶어 달력에 아이콘 표시.
                    final usedByDate = <String, List<Map<String, dynamic>>>{};
                    for (final u in invSnap.data ?? <Map<String, dynamic>>[]) {
                      if (u['used'] == true && u['usedDate'] != null) {
                        (usedByDate[u['usedDate'] as String] ??= []).add(u);
                      }
                    }
                    final prizeEmojis = usedByDate.map((k, v) =>
                        MapEntry(k, v.map((e) => (e['emoji'] ?? '🎁').toString()).toList()));
                    final dayPrizes = usedByDate[selectedKey] ?? const <Map<String, dynamic>>[];
                    return ListView(
                  children: [
                    _MonthHeader(
                      month: _month,
                      onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                    ),
                    _MonthGrid(
                      month: _month,
                      selected: _selected,
                      markedDates: dates,
                      prizeEmojis: prizeEmojis,
                      onTap: (d) => setState(() => _selected = d),
                    ),
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(DateFormat('M월 d일 (E)', 'ko').format(_selected), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    // 이 날 사용 완료한 상품(아이콘 + 이름 + 사용자)
                    for (final p in dayPrizes)
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        color: const Color(0xFFF1F8E9),
                        child: ListTile(
                          leading: Text((p['emoji'] ?? '🎁').toString(), style: const TextStyle(fontSize: 26)),
                          title: Text((p['name'] ?? '상품').toString()),
                          subtitle: Text('${nickOf(p['ownerId'] as String?)} 사용 완료 🎁'),
                        ),
                      ),
                    if (dayEntries.isEmpty && dayPrizes.isEmpty)
                      const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('이 날은 기록이 없어요.')))
                    else if (dayEntries.isNotEmpty) ...[
                      if (!bothDrew)
                        Card(
                          color: Colors.amber.shade50,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              dayIds.contains(partnerId) && !dayIds.contains(myId)
                                  ? '🔒 ${nickOf(partnerId)}님 그림은 나도 그려야 공개돼요.'
                                  : '🔒 둘 다 그려야 서로의 그림이 공개돼요.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ...visibleEntries.map((e) => _EntryCard(entry: e)),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
                  },
                );
              },
            ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext;
  const _MonthHeader({required this.month, required this.onPrev, required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Text(DateFormat('yyyy년 M월', 'ko').format(month), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final Set<String> markedDates;
  final Map<String, List<String>> prizeEmojis; // 날짜 → 사용한 상품 아이콘들
  final ValueChanged<DateTime> onTap;
  const _MonthGrid({required this.month, required this.selected, required this.markedDates, required this.prizeEmojis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7; // 일요일 시작(0)
    final cells = <Widget>[];

    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    for (final l in labels) {
      cells.add(Center(child: Text(l, style: TextStyle(fontSize: 12, color: l == '일' ? Colors.red : (l == '토' ? Colors.blue : Colors.grey)))));
    }
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final d = DateTime(month.year, month.month, day);
      final key = DateFormat('yyyy-MM-dd').format(d);
      final isSel = selected.year == d.year && selected.month == d.month && selected.day == d.day;
      final marked = markedDates.contains(key);
      final prizes = prizeEmojis[key] ?? const <String>[];
      cells.add(GestureDetector(
        onTap: () => onTap(d),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSel ? Theme.of(context).colorScheme.primary : null,
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day', style: TextStyle(color: isSel ? Colors.white : null, fontSize: 13)),
              if (prizes.isNotEmpty)
                Text(
                  prizes.length > 2 ? '${prizes.take(2).join()}…' : prizes.join(),
                  style: const TextStyle(fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                )
              else if (marked)
                Container(width: 5, height: 5, decoration: BoxDecoration(color: isSel ? Colors.white : Colors.pink, shape: BoxShape.circle)),
            ],
          ),
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cells,
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final Entry entry;
  const _EntryCard({required this.entry});
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.4,
            child: EntryImage(b64: entry.imageB64),
          ),
          ListTile(
            title: Text(entry.topic),
            subtitle: Text('${entry.author} · ${DateFormat('HH:mm').format(entry.createdAt)}'),
          ),
        ],
      ),
    );
  }
}
