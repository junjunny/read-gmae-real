import 'package:cloud_firestore/cloud_firestore.dart';

/// 전송된 그림 1점. Firestore `couples/{id}/drawings/{drawingId}` 문서에 대응.
class Drawing {
  final String id;
  final String authorUid;
  final String authorName;
  final String date; // yyyy-MM-dd
  final String topic;
  final String imageUrl; // Storage 원본
  final String thumbUrl;
  final DateTime createdAt;

  Drawing({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.date,
    required this.topic,
    required this.imageUrl,
    required this.thumbUrl,
    required this.createdAt,
  });

  factory Drawing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Drawing(
      id: doc.id,
      authorUid: d['authorUid'] ?? '',
      authorName: d['authorName'] ?? '',
      date: d['date'] ?? '',
      topic: d['topic'] ?? '',
      imageUrl: d['imageUrl'] ?? '',
      thumbUrl: d['thumbUrl'] ?? d['imageUrl'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorUid': authorUid,
        'authorName': authorName,
        'date': date,
        'topic': topic,
        'imageUrl': imageUrl,
        'thumbUrl': thumbUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
