import 'package:cloud_firestore/cloud_firestore.dart';

/// 제출된 그림 1점. Firestore `rooms/{roomId}/entries/{id}`.
class Entry {
  final String id;
  final String author; // 닉네임 (표시용)
  final String authorId; // 0421 / 0118 (포인트 적립 기준)
  final String date; // yyyy-MM-dd
  final String topic;
  final String imageB64; // PNG base64 (Storage 대신 Firestore에 직접 저장)
  final DateTime createdAt;

  Entry({
    required this.id,
    required this.author,
    required this.authorId,
    required this.date,
    required this.topic,
    required this.imageB64,
    required this.createdAt,
  });

  factory Entry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Entry(
      id: doc.id,
      author: d['author'] ?? '',
      authorId: d['authorId'] ?? '',
      date: d['date'] ?? '',
      topic: d['topic'] ?? '',
      imageB64: d['imageB64'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'author': author,
        'authorId': authorId,
        'date': date,
        'topic': topic,
        'imageB64': imageB64,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
