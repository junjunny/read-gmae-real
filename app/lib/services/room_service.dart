import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/entry.dart';
import '../util/users.dart';
import 'session_prefs.dart';

/// 방(초대코드) 단위 그림 저장/조회. Storage 없이 Firestore에 base64로 저장(무료).
class RoomService {
  final _db = FirebaseFirestore.instance;

  String get _room => SessionPrefs.roomId ?? 'default';

  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('rooms').doc(_room).collection('entries');

  /// 제출: PNG 바이트를 base64로 Firestore 문서에 저장.
  Future<void> submit({
    required Uint8List pngBytes,
    required String topic,
    required String date,
  }) async {
    final docRef = _entries.doc();
    final entry = Entry(
      id: docRef.id,
      author: nickOf(SessionPrefs.userId),
      authorId: SessionPrefs.userId ?? '',
      date: date,
      topic: topic,
      imageB64: base64Encode(pngBytes),
      createdAt: DateTime.now(),
    );
    await docRef.set(entry.toMap());
  }

  /// 전체(최신순).
  Stream<List<Entry>> watchAll() {
    return _entries
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Entry.fromDoc).toList());
  }

  /// 특정 날짜의 제출들.
  Stream<List<Entry>> watchByDate(String date) {
    return _entries
        .where('date', isEqualTo: date)
        .snapshots()
        .map((s) => s.docs.map(Entry.fromDoc).toList());
  }
}
