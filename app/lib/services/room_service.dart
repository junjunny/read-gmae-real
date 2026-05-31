import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/entry.dart';
import '../util/users.dart';
import 'session_prefs.dart';

/// 방(초대코드) 단위로 그림을 저장/조회. 로그인 불필요.
class RoomService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String get _room => SessionPrefs.roomId ?? 'default';

  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('rooms').doc(_room).collection('entries');

  /// 제출: PNG 업로드 → Firestore 문서 생성.
  Future<void> submit({
    required Uint8List pngBytes,
    required String topic,
    required String date,
  }) async {
    final docRef = _entries.doc();
    final path = 'rooms/$_room/${docRef.id}.png';
    final task = await _storage
        .ref(path)
        .putData(pngBytes, SettableMetadata(contentType: 'image/png'));
    final url = await task.ref.getDownloadURL();

    final entry = Entry(
      id: docRef.id,
      author: nickOf(SessionPrefs.userId),
      authorId: SessionPrefs.userId ?? '',
      date: date,
      topic: topic,
      imageUrl: url,
      createdAt: DateTime.now(),
    );
    await docRef.set(entry.toMap());
  }

  /// 전체(최신순) — 달력 마킹/히스토리에 사용.
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
