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

  DocumentReference<Map<String, dynamic>> get _profilesRef =>
      _db.collection('rooms').doc(_room).collection('meta').doc('profiles');

  /// 두 사람의 프로필 사진(base64) 공유.
  Stream<Map<String, String?>> watchProfiles() => _profilesRef.snapshots().map((d) {
        final m = d.data() ?? {};
        return {'0421': m['0421'] as String?, '0118': m['0118'] as String?};
      });

  Future<void> setProfile(String userId, String b64) =>
      _profilesRef.set({userId: b64}, SetOptions(merge: true));

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
  /// 게임 상태: 두 사람의 현재 라운드 점수 + 최근 정산 결과 메시지.
  Stream<Map<String, dynamic>> watchGame(String key) => _gameRef(key).snapshots().map((d) {
        final m = d.data() ?? {};
        return {
          '0421': m['0421'] as int?,
          '0118': m['0118'] as int?,
          'lastResult': m['lastResult'] as String?,
        };
      });

  static String _nick(String uid) => uid == '0421' ? '주니' : '히수';

  /// 점수 제출 → 둘 다 모이면 **자동 정산**(높은 점수 +10, 낮은 점수 -5, 라운드 초기화).
  /// 반환: 정산 결과 메시지(상대 점수 없으면 '대기' 안내).
  Future<String> submitScoreAuto(String key, String userId, int score) async {
    final other = userId == '0421' ? '0118' : '0421';
    return _db.runTransaction((tx) async {
      final gRef = _gameRef(key);
      final g = await tx.get(gRef);
      final p = await tx.get(_pointsRef); // 읽기는 쓰기 전에 모두
      final otherScore = g.data()?[other];

      if (otherScore == null) {
        // 상대 점수 없음 → 내 점수만 기록(이전 정산 메시지는 지움)
        tx.set(gRef, {userId: score, 'lastResult': FieldValue.delete()}, SetOptions(merge: true));
        return '점수 $score점 등록! 상대가 플레이하면 자동 정산돼요.';
      }

      // 둘 다 있음 → 자동 정산
      final pd = Map<String, dynamic>.from(p.data() ?? {});
      int cur(String u) => (pd[u] ?? 0) as int;
      final scores = {userId: score, other: (otherScore as num).toInt()};
      final s0421 = scores['0421']!;
      final s0118 = scores['0118']!;
      String msg;
      if (s0421 == s0118) {
        msg = '무승부! (주니 $s0421 : 히수 $s0118) 변동 없음';
      } else {
        final win = s0421 > s0118 ? '0421' : '0118';
        final lose = win == '0421' ? '0118' : '0421';
        pd[win] = cur(win) + 10;
        pd[lose] = cur(lose) - 5;
        msg = '주니 $s0421 : 히수 $s0118 → ${_nick(win)} +10, ${_nick(lose)} -5';
      }
      tx.set(_pointsRef, pd);
      // 라운드 점수 초기화 + 결과 기록(둘 다 볼 수 있게)
      tx.set(gRef, {
        '0421': FieldValue.delete(),
        '0118': FieldValue.delete(),
        'lastResult': msg,
      }, SetOptions(merge: true));
      return msg;
    });
  }
}
