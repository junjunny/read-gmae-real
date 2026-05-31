import 'package:cloud_firestore/cloud_firestore.dart';

import 'gemini_service.dart';
import 'session_prefs.dart';

/// 명언 필사 채점 결과.
enum QuoteResult { ok, already, mismatch, noQuote }

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

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _db.collection('rooms').doc(_room).collection('meta').doc('config');

  /// Gemini API 키 (비공개 Firestore에만 저장).
  Future<String?> getGeminiKey() async {
    final s = await _configRef.get();
    return s.data()?['geminiKey'] as String?;
  }

  Future<void> setGeminiKey(String key) =>
      _configRef.set({'geminiKey': key}, SetOptions(merge: true));

  Future<String?> getVapidKey() async {
    final s = await _configRef.get();
    return s.data()?['vapidKey'] as String?;
  }

  /// FCM 토큰 저장 (rooms/{room}/meta/tokens).
  Future<void> saveToken(String userId, String token) => _db
      .collection('rooms')
      .doc(_room)
      .collection('meta')
      .doc('tokens')
      .set({userId: token}, SetOptions(merge: true));

  /// 콕 찌르기: 큐에 넣으면 무료 크론이 ~10분 내 상대에게 푸시.
  Future<void> sendPoke(String fromUid, String toUid, String message) => _db
      .collection('rooms')
      .doc(_room)
      .collection('pokes')
      .add({
        'from': fromUid,
        'to': toUid,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      });

  DocumentReference<Map<String, dynamic>> get _recordsRef =>
      _db.collection('rooms').doc(_room).collection('meta').doc('records');

  /// 역대 최고기록(월드레코드): { gameKey: {score, holder} }
  Stream<Map<String, Map<String, dynamic>>> watchRecords() => _recordsRef.snapshots().map((d) {
        final m = d.data() ?? {};
        return m.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
      });

  /// 역대 기록 갱신(더 높으면). 월드레코드 갱신 시 즉시 +100P.
  /// 반환: 신기록이면 true.
  Future<bool> updateRecord(String key, String userId, int score) async {
    return _db.runTransaction((tx) async {
      final s = await tx.get(_recordsRef);
      final cur = (s.data()?[key]?['score'] ?? -1) as int;
      if (score <= cur) return false;
      // 즉시 +100P
      final p = await tx.get(_pointsRef);
      final curPt = (p.data()?[userId] ?? 0) as int;
      tx.set(_pointsRef, {userId: curPt + 100}, SetOptions(merge: true));
      tx.set(_recordsRef, {
        key: {'score': score, 'holder': userId}
      }, SetOptions(merge: true));
      return true;
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

  // ---- 오늘의 명언 (필사 +50P) ----
  /// rooms/{room}/quotes/{date}  { text, claimed: {'0421':bool,'0118':bool} }
  DocumentReference<Map<String, dynamic>> _quoteRef(String date) =>
      _db.collection('rooms').doc(_room).collection('quotes').doc(date);

  /// 오늘의 명언 스트림.
  Stream<Map<String, dynamic>?> watchTodayQuote() =>
      _quoteRef(kstToday()).snapshots().map((d) => d.data());

  /// 오늘의 명언이 없으면 Gemini로 1개 생성해 저장(앱 실행 시 자정 경과분 체크).
  /// 키가 없거나 실패하면 조용히 넘어감(메뉴 추천에서 키를 등록하면 다음날부터 동작).
  Future<void> ensureTodayQuote() async {
    final date = kstToday();
    final ref = _quoteRef(date);
    final snap = await ref.get();
    if (snap.exists && (snap.data()?['text'] as String?)?.isNotEmpty == true) return;

    if (!GeminiService.hasKey) {
      GeminiService.apiKey = await getGeminiKey();
      if (!GeminiService.hasKey) return;
    }
    String text;
    try {
      text = await GeminiService.generate(
          '오늘의 명언(좋은 글귀)을 딱 1개만 한국어로 알려줘. '
          '형식은 "명언 - 저자" 한 줄. 40자 이내로 짧고 필사하기 좋게. '
          '따옴표나 설명, 다른 말은 절대 붙이지 마.');
    } catch (_) {
      return;
    }
    text = text.replaceAll('\n', ' ').replaceAll('"', '').replaceAll('“', '').replaceAll('”', '').trim();
    if (text.isEmpty) return;
    // 그 사이 상대가 먼저 생성했을 수 있으니 없을 때만 기록.
    await _db.runTransaction((tx) async {
      final s = await tx.get(ref);
      if (s.exists && (s.data()?['text'] as String?)?.isNotEmpty == true) return;
      tx.set(ref, {'text': text, 'claimed': <String, dynamic>{}, 'createdAt': FieldValue.serverTimestamp()});
    });
  }

  /// 필사 채점: 띄어쓰기 포함 정확히 일치하면 +50P(하루 1회). 양끝 공백만 무시.
  Future<QuoteResult> claimQuote(String userId, String typed) async {
    final date = kstToday();
    final ref = _quoteRef(date);
    return _db.runTransaction((tx) async {
      final qs = await tx.get(ref);
      final text = (qs.data()?['text'] as String?)?.trim();
      if (text == null || text.isEmpty) return QuoteResult.noQuote;
      final claimed = Map<String, dynamic>.from(qs.data()?['claimed'] ?? {});
      if (claimed[userId] == true) return QuoteResult.already;
      if (typed.trim() != text) return QuoteResult.mismatch;

      final ps = await tx.get(_pointsRef);
      final cur = (ps.data()?[userId] ?? 0) as int;
      tx.set(_pointsRef, {userId: cur + 50}, SetOptions(merge: true));
      claimed[userId] = true;
      tx.set(ref, {'claimed': claimed}, SetOptions(merge: true));
      return QuoteResult.ok;
    });
  }

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
        delta[u] = delta[u]! + 50;
      }
    }
    if (drew.isNotEmpty) parts.add('그림 ${drew.map(_nick).join('·')} +50');

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
