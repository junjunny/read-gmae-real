import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_session.dart';

/// 커플 페어링: 한 명이 코드를 만들고, 상대가 그 코드로 합류한다.
class CoupleService {
  final _db = FirebaseFirestore.instance;

  /// 6자리 페어 코드 생성(혼동되는 글자 제외). seed로 결정적 생성(테스트 가능).
  String _genCode(int seed) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buf = StringBuffer();
    var x = seed;
    for (var i = 0; i < 6; i++) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      buf.write(chars[x % chars.length]);
    }
    return buf.toString();
  }

  /// 커플 방 생성 → pairCode 반환.
  Future<String> createCouple(String uid) async {
    final ref = _db.collection('couples').doc();
    final code = _genCode(ref.id.hashCode ^ uid.hashCode);
    await ref.set({
      'members': [uid],
      'pairCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(uid).update({'coupleId': ref.id});
    AppSession.instance.coupleId = ref.id;
    return code;
  }

  /// 코드로 기존 커플 방에 합류.
  Future<void> joinByCode(String uid, String code) async {
    final q = await _db
        .collection('couples')
        .where('pairCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (q.docs.isEmpty) {
      throw Exception('코드를 찾을 수 없어요. 다시 확인해주세요.');
    }
    final couple = q.docs.first;
    final members = List<String>.from(couple['members'] ?? []);
    if (members.length >= 2 && !members.contains(uid)) {
      throw Exception('이미 두 명이 연결된 방이에요.');
    }
    await couple.reference.update({
      'members': FieldValue.arrayUnion([uid]),
    });
    await _db.collection('users').doc(uid).update({'coupleId': couple.id});
    AppSession.instance.coupleId = couple.id;
  }

  Future<String?> pairCodeOf(String coupleId) async {
    final doc = await _db.collection('couples').doc(coupleId).get();
    return doc.data()?['pairCode'];
  }
}
