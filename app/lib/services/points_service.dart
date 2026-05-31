import 'package:cloud_firestore/cloud_firestore.dart';

import 'session_prefs.dart';

/// 포인트 + 미니게임 점수 (Firestore 공유).
/// 포인트: rooms/{room}/meta/points  { '0421': n, '0118': n }
/// 게임점수: rooms/{room}/games/{gameKey}  { '0421': score, '0118': score }
class PointsService {
  final _db = FirebaseFirestore.instance;
  String get _room => SessionPrefs.roomId ?? 'default';

  DocumentReference<Map<String, dynamic>> get _pointsRef =>
      _db.collection('rooms').doc(_room).collection('meta').doc('points');
  DocumentReference<Map<String, dynamic>> _gameRef(String key) =>
      _db.collection('rooms').doc(_room).collection('games').doc(key);

  Stream<Map<String, int>> watchPoints() => _pointsRef.snapshots().map((d) {
        final m = d.data() ?? {};
        return {
          '0421': (m['0421'] ?? 0) as int,
          '0118': (m['0118'] ?? 0) as int,
        };
      });

  /// 포인트 증감.
  Future<void> addPoints(String userId, int delta) async {
    await _db.runTransaction((tx) async {
      final s = await tx.get(_pointsRef);
      final cur = (s.data()?[userId] ?? 0) as int;
      tx.set(_pointsRef, {userId: cur + delta}, SetOptions(merge: true));
    });
  }

  /// 포인트 차감(부족하면 false).
  Future<bool> spend(String userId, int cost) async {
    return _db.runTransaction((tx) async {
      final s = await tx.get(_pointsRef);
      final cur = (s.data()?[userId] ?? 0) as int;
      if (cur < cost) return false;
      tx.set(_pointsRef, {userId: cur - cost}, SetOptions(merge: true));
      return true;
    });
  }

  // ---- 미니게임 점수 ----
  Stream<Map<String, int?>> watchGame(String key) => _gameRef(key).snapshots().map((d) {
        final m = d.data() ?? {};
        return {'0421': m['0421'] as int?, '0118': m['0118'] as int?};
      });

  Future<void> submitScore(String key, String userId, int score) async {
    // 더 높은 점수만 갱신(자기 베스트)
    await _db.runTransaction((tx) async {
      final s = await tx.get(_gameRef(key));
      final prev = (s.data()?[userId] ?? -1) as int;
      if (score > prev) tx.set(_gameRef(key), {userId: score}, SetOptions(merge: true));
    });
  }

  /// 정산: 둘 다 점수 있으면 높은 쪽 +10, 낮은 쪽 -5, 점수 초기화. 결과 메시지 반환.
  Future<String> settle(String key) async {
    return _db.runTransaction((tx) async {
      final gRef = _gameRef(key);
      final g = await tx.get(gRef);
      final s1 = g.data()?['0421'];
      final s2 = g.data()?['0118'];
      if (s1 == null || s2 == null) return '두 명 모두 점수가 있어야 정산돼요.';
      final p = await tx.get(_pointsRef);
      final pd = Map<String, dynamic>.from(p.data() ?? {});
      int cur(String u) => (pd[u] ?? 0) as int;
      final n1 = s1 as num;
      final n2 = s2 as num;
      String msg;
      if (n1 == n2) {
        msg = '무승부! 포인트 변동 없음';
      } else {
        final win = n1 > n2 ? '0421' : '0118';
        final lose = win == '0421' ? '0118' : '0421';
        pd[win] = cur(win) + 10;
        pd[lose] = cur(lose) - 5;
        msg = '${win == '0421' ? '주니' : '히수'} +10 / ${lose == '0421' ? '주니' : '히수'} -5';
      }
      tx.set(_pointsRef, pd);
      tx.set(gRef, {'0421': FieldValue.delete(), '0118': FieldValue.delete()}, SetOptions(merge: true));
      return msg;
    });
  }
}
