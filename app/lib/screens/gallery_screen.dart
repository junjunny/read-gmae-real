import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/drawing.dart';
import '../services/drawing_service.dart';
import 'detail_screen.dart';

/// 히스토리 갤러리 (요구사항 4): 월별 섹션 + 그리드. 평생 보관된 그림 모아보기.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _service = DrawingService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('우리의 추억')),
      body: StreamBuilder<List<Drawing>>(
        stream: _service.watchAll(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('아직 그림이 없어요. 첫 그림을 그려보세요! 🎨'));
          }
          // 월별 그룹핑
          final groups = <String, List<Drawing>>{};
          for (final d in items) {
            final key = DateFormat('yyyy년 M월').format(d.createdAt);
            groups.putIfAbsent(key, () => []).add(d);
          }
          final keys = groups.keys.toList();

          return ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, i) {
              final month = keys[i];
              final list = groups[month]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(month, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, j) => _Tile(drawing: list[j]),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Drawing drawing;
  const _Tile({required this.drawing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(drawing: drawing)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: drawing.thumbUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade200),
            ),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  DateFormat('d일').format(drawing.createdAt),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
