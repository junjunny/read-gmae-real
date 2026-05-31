import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/drawing.dart';
import 'app_session.dart';

/// 그림 업로드/조회 + 오늘의 주제 조회.
class DrawingService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _drawings(String coupleId) =>
      _db.collection('couples').doc(coupleId).collection('drawings');

  /// PNG 바이트를 Storage에 올리고 Firestore 문서를 생성.
  Future<Drawing> sendDrawing({
    required Uint8List pngBytes,
    required String topic,
    required String date,
  }) async {
    final s = AppSession.instance;
    final coupleId = s.coupleId!;
    final docRef = _drawings(coupleId).doc();

    final path = 'couples/$coupleId/drawings/${docRef.id}.png';
    final task = await _storage.ref(path).putData(
          pngBytes,
          SettableMetadata(contentType: 'image/png'),
        );
    final url = await task.ref.getDownloadURL();

    final drawing = Drawing(
      id: docRef.id,
      authorUid: s.uid!,
      authorName: s.displayName ?? '익명',
      date: date,
      topic: topic,
      imageUrl: url,
      thumbUrl: url,
      createdAt: DateTime.now(),
    );
    await docRef.set(drawing.toMap());
    return drawing;
  }

  /// 히스토리: 최신순 전체 스트림.
  Stream<List<Drawing>> watchAll() {
    final coupleId = AppSession.instance.coupleId!;
    return _drawings(coupleId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Drawing.fromDoc).toList());
  }

  /// 위젯/오늘탭: 상대가 보낸 최신 그림 1점.
  Stream<Drawing?> watchPartnerLatest() {
    final s = AppSession.instance;
    return _drawings(s.coupleId!)
        .where('authorUid', isNotEqualTo: s.uid)
        .orderBy('authorUid')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : Drawing.fromDoc(snap.docs.first));
  }

  /// 오늘의 주제 (Cloud Function이 매일 08시에 기록).
  Stream<String?> watchTodayTopic(String date) {
    final coupleId = AppSession.instance.coupleId!;
    return _db
        .collection('couples')
        .doc(coupleId)
        .collection('dailyTopics')
        .doc(date)
        .snapshots()
        .map((doc) => doc.data()?['topic'] as String?);
  }
}
