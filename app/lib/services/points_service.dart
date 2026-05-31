import 'package:cloud_firestore/cloud_firestore.dart';

import 'session_prefs.dart';

/// 포인트 + 프로필 + 미니게임(일일 베스트, 자정 정산).
/// - 포인트: rooms/{room}/meta/points  { '0421': n, '0118': n }
/// - 프로필: rooms/{room}/meta/profiles { '0421': b64, '0118': b64 }
/// - 일일 점수: rooms/{room}/days/{date}  { games: { key: {'0421':best,'0118':best} } }
/// - 정산 상태: rooms/{room}/meta/state  { lastSettledDate, lastSummary }
class PointsService {
  final _db = FirebaseFirestore.instance;
  String get _room => SessionPrefs.roomId ?? 'default';

  DocumentReference<Map<String, dynamic>> get _pointsRef =>
      _db.collection('rooms').doc(_room).collection('meta').doc('points');
  DocumentReference<Map<String, dynamic>> get _profilesRef =>
      _db.collection('rooms').doc(_room).collection('meta').doc('profiles');
  DocumentReference<Map<String, dynamic>> get _stateRef =>
      _db.collection('rooms').doc(_room).collection('meta').doc('state');
  DocumentReference<Map<String, dynamic>> _dayRef(String date) =>
      _db.collection('rooms').doc(_room).collection('days').doc(date);

  static String _nick(String uid) => uid == '0421' ? '주니' : '히수';

  // ---- 날짜(KST) 유틸 ----
  static String _pad(int n) => n.toString().padLeft(2, '0');
  static String _fmt(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
  static DateTime _parse(String s) {
    final p = s.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static String kstToday() => _fmt(DateTime.now().toUtc().add(const Duration(hours: 9)));
  static String _next(String s) => _fmt(_parse(s).add(const Duration(days: 1)));
  static String _prev(String s) => _fmt(_parse(s).subtract(const Duration(days: 1)));

  // ---- 포인트 ----
  Stream<Map<String, int>> watchPoints() => _pointsRef.snapshots().map((d) {
        final m = d.data() ?? {};
        return {'0421': (m['0421'] ?? 0) as int, '0118': (m['0118'] ?? 0) as int};
      });

  Future<bool> spend(String userId, int cost) async {
    return _db.runTransaction((tx) async {
      final s = await tx.get(_pointsRef);
      final cur = (s.data()?[userId] ?? 0) as int;
      if (cur < cost) return false;
      tx.set(_pointsRef, {userId: cur - cost}, SetOptions(merge: true));
      return true;
    });
  }

  // ---- 프로필 ----
  Stream<Map<String, String?>> watchProfiles() => _profilesRef.snapshots().map((d) {
        final m = d.data() ?? {};
        return {'0421': m['0421'] as String?, '0118': m['0118'] as String?};
      });
  Future<void> setProfile(String userId, String b64) =>
      _profilesRef.set({userId: b64}, SetOptions(merge: true));

  // ---- 미니게임 (오늘 베스트) ----
  /// 오늘 점수 기록 — 기존보다 높으면 갱신(하루 동안 계속 도전 가능).
  Future<void> submitBest(String key, String userId, int score) async {
    final ref = _dayRef(kstToday());
    await _db.runTransaction((tx) async {
      final s = await tx.get(ref);
      final games = Map<String, dynamic>.from(s.data()?['games'] ?? {});
      final g = Map<String, dynamic>.from(games[key] ?? {});
      final prev = (g[userId] ?? -1) as int;
      if (score > prev) {
        g[userId] = score;
        games[key] = g;
        tx.set(ref, {'games': games}, SetOptions(merge: true));
      }
    });
  }

  DocumentReference<Map<String, dynamic>> get _recordsRef =>
      _db.collection('rooms').doc(_room).collection('meta').doc('records');

  /// 역대 최고기록(월드레코드): { gameKey: {score, holder} }
  Stream<Map<String, Map<String, dynamic>>> watchRecords() => _recordsRef.snapshots().map((d) {
        final m = d.data() ?? {};
        return m.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
      });

  /// 역대 기록 갱신(더 높으면).
  Future<void> updateRecord(String key, String userId, int score) async {
    await _db.runTransaction((tx) async {
      final s = await tx.get(_recordsRef);
      final cur = (s.data()?[key]?['score'] ?? -1) as int;
      if (score > cur) {
        tx.set(_recordsRef, {
          key: {'score': score, 'holder': userId}
        }, SetOptions(merge: true));
      }
    });
  }

  /// 오늘 게임별 베스트 점수 스트림: { gameKey: {'0421':?, '0118':?} }
  Stream<Map<String, Map<String, int?>>> watchTodayGames() {
    return _dayRef(kstToday()).snapshots().map((d) {
      final games = (d.data()?['games'] ?? {}) as Map<String, dynamic>;
      return games.map((k, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(k, {'0421': m['0421'] as int?, '0118': m['0118'] as int?});
      });
    });
  }

  /// 최근 정산 요약(어제 결과 등) 스트림.
  Stream<String?> watchLastSummary() =>
      _stateRef.snapshots().map((d) => d.data()?['lastSummary'] as String?);

  // ---- 자정 정산 (지난 날짜 처리) ----
  /// 앱이 열릴 때 호출. 어제까지의 미정산 날짜를 정산한다.
  Future<void> settlePending() async {
    final today = kstToday();
    final yesterday = _prev(today);
    final stateSnap = await _stateRef.get();
    final last = stateSnap.data()?['lastSettledDate'] as String?;

    if (last == null) {
      // 첫 실행: 어제로 표시 → 오늘부터 집계, 내일 자정 정산
      await _stateRef.set({'lastSettledDate': yesterday}, SetOptions(merge: true));
      return;
    }
    if (last.compareTo(yesterday) >= 0) return; // 이미 어제까지 정산됨

    final summaries = <String>[];
    var d = _next(last);
    var guard = 0;
    while (d.compareTo(today) < 0 && guard < 31) {
      final msg = await _settleDay(d);
      if (msg != null) summaries.add('$d → $msg');
      d = _next(d);
      guard++;
    }
    await _stateRef.set({
      'lastSettledDate': yesterday,
      if (summaries.isNotEmpty) 'lastSummary': summaries.join('\n'),
    }, SetOptions(merge: true));
  }

  /// 하루치 정산: 게임 승패(+10/-5) + 그림 참여(+5), 포인트 반영 후 그날 데이터 삭제.
  Future<String?> _settleDay(String date) async {
    final daySnap = await _dayRef(date).get();
    final games = (daySnap.data()?['games'] ?? {}) as Map<String, dynamic>;

    // 그림 참여(그날 제출자)
    final entries = await _db
        .collection('rooms')
        .doc(_room)
        .collection('entries')
        .where('date', isEqualTo: date)
        .get();
    final drew = entries.docs.map((e) => e.data()['authorId'] as String?).whereType<String>().toSet();

    final delta = {'0421': 0, '0118': 0};
    final parts = <String>[];

    games.forEach((key, v) {
      final m = v as Map<String, dynamic>;
      final s1 = m['0421'] as int?;
      final s2 = m['0118'] as int?;
      if (s1 == null && s2 == null) return;
      if (s1 != null && s2 != null) {
        if (s1 == s2) {
          parts.add('$key:무');
          return;
        }
        final win = s1 > s2 ? '0421' : '0118';
        final lose = win == '0421' ? '0118' : '0421';
        delta[win] = delta[win]! + 10;
        delta[lose] = delta[lose]! - 5;
        parts.add('$key:${_nick(win)}승');
      } else {
        // 한쪽만 플레이 → 안 한 사람 자동 패배
        final win = s1 != null ? '0421' : '0118';
        final lose = win == '0421' ? '0118' : '0421';
        delta[win] = delta[win]! + 10;
        delta[lose] = delta[lose]! - 5;
        parts.add('$key:${_nick(win)}승(${_nick(lose)}미플레이)');
      }
    });
    for (final u in ['0421', '0118']) {
      if (drew.contains(u)) {
        delta[u] = delta[u]! + 5;
      }
    }
    if (drew.isNotEmpty) parts.add('그림 ${drew.map(_nick).join('·')} +5');

    // 역대 월드레코드 갱신(그날 베스트와 비교)
    if (games.isNotEmpty) {
      await _db.runTransaction((tx) async {
        final r = await tx.get(_recordsRef);
        final rd = Map<String, dynamic>.from(r.data() ?? {});
        var changed = false;
        games.forEach((key, v) {
          final m = v as Map<String, dynamic>;
          for (final u in ['0421', '0118']) {
            final sc = m[u] as int?;
            if (sc != null) {
              final cur = (rd[key]?['score'] ?? -1) as int;
              if (sc > cur) {
                rd[key] = {'score': sc, 'holder': u};
                changed = true;
              }
            }
          }
        });
        if (changed) tx.set(_recordsRef, rd);
      });
    }

    if (delta['0421'] == 0 && delta['0118'] == 0) {
      await _dayRef(date).delete();
      return parts.isEmpty ? null : parts.join(', ');
    }
    await _db.runTransaction((tx) async {
      final p = await tx.get(_pointsRef);
      final pd = Map<String, dynamic>.from(p.data() ?? {});
      pd['0421'] = ((pd['0421'] ?? 0) as int) + delta['0421']!;
      pd['0118'] = ((pd['0118'] ?? 0) as int) + delta['0118']!;
      tx.set(_pointsRef, pd);
    });
    await _dayRef(date).delete();
    return parts.join(', ');
  }
}
