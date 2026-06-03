import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models/entry.dart';
import '../services/image_export.dart';
import '../services/room_service.dart';
import '../services/session_prefs.dart';
import '../util/daily_topic.dart';
import '../util/users.dart';
import '../widgets/entry_image.dart';
import 'canvas_screen.dart';

/// 오늘의 그림: 오늘의 주제 + 그리기 + 오늘 제출 현황.
class DrawingTodayScreen extends StatelessWidget {
  const DrawingTodayScreen({super.key});

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final topic = topicForDate(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 그림')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('🎯 오늘의 주제', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(topic, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    icon: const Icon(Icons.brush),
                    label: const Text('이 주제로 그리기'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _openCanvas(context, topic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('💌 오늘의 그림', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (!firebaseReady) const _NoticeCard() else _TodayEntries(date: _today),
        ],
      ),
    );
  }

  void _openCanvas(BuildContext context, String topic) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CanvasScreen(
        topic: topic,
        onSubmit: firebaseReady
            ? (Uint8List png) async {
                await RoomService().submit(pngBytes: png, topic: topic, date: _today);
                return true;
              }
            : null,
      ),
    ));
  }
}

class _TodayEntries extends StatelessWidget {
  final String date;
  const _TodayEntries({required this.date});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Entry>>(
      stream: RoomService().watchByDate(date),
      builder: (context, snap) {
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        final items = snap.data!;
        if (items.isEmpty) {
          return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('아직 오늘 제출된 그림이 없어요.\n먼저 그려서 제출해보세요! ✏️', textAlign: TextAlign.center))));
        }
        // 둘 다 제출하기 전까지 상대 그림은 비공개(내 그림은 항상 보임).
        final myId = SessionPrefs.userId ?? '0421';
        final ids = items.map((e) => e.authorId).toSet();
        final bothDrew = ids.contains('0421') && ids.contains('0118');
        final visible = bothDrew ? items : items.where((e) => e.authorId == myId).toList();
        final partnerId = myId == '0421' ? '0118' : '0421';
        final partnerDrew = ids.contains(partnerId);
        return Column(
          children: [
            if (!bothDrew)
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('🔒', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          partnerDrew
                              ? '${nickOf(partnerId)}님은 그렸어요! 나도 그려야 서로의 그림이 공개돼요 🎨'
                              : '둘 다 그려야 서로의 그림이 공개돼요. 먼저 그려보세요! ✏️',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ...visible.map((e) => Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        AspectRatio(aspectRatio: 1.4, child: EntryImage(b64: e.imageB64)),
                        ListTile(
                          leading: const Icon(Icons.brush),
                          title: Text(e.author),
                          subtitle: Text(DateFormat('HH:mm').format(e.createdAt)),
                          trailing: OutlinedButton.icon(
                            onPressed: () => _save(context, e),
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('저장'),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        );
      },
    );
  }

  // 그림(base64 PNG)을 저장 — 웹은 브라우저 다운로드, 모바일은 사진첩.
  Future<void> _save(BuildContext context, Entry e) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = base64Decode(e.imageB64);
      final ok = await saveImageBytes(bytes, '오늘의그림_${e.author}_$date.png');
      messenger.showSnackBar(SnackBar(content: Text(ok ? '${e.author}님 그림을 저장했어요 💾' : '저장에 실패했어요')));
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $err')));
    }
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(children: [Icon(Icons.cloud_off, color: Colors.amber), SizedBox(height: 8), Text('지금은 그리기·저장만 됩니다.', textAlign: TextAlign.center)]),
      ),
    );
  }
}
