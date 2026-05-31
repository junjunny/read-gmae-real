import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../models/stroke.dart';
import '../services/drawing_service.dart';
import '../services/image_export.dart';
import '../widgets/drawing_painter.dart';

/// 메인 캔버스 (요구사항 3) + 전송(Firebase 업로드).
class CanvasScreen extends StatefulWidget {
  final String topic;
  /// Firebase 미설정 시 로컬 모드(전송 비활성, 그리기·저장만).
  final bool localOnly;
  const CanvasScreen({super.key, this.topic = '지금 생각나는 동물 그리기', this.localOnly = false});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final GlobalKey _canvasKey = GlobalKey();

  final List<Stroke> _strokes = [];
  final List<Stroke> _redoStack = [];
  Stroke? _current;

  Color _color = Colors.black;
  double _width = 4.0;
  bool _eraser = false;
  Color _bg = Colors.white;
  bool _sending = false;

  static const _palette = [
    Colors.black,
    Color(0xFFE57373),
    Color(0xFFFFB74D),
    Color(0xFFFFF176),
    Color(0xFF81C784),
    Color(0xFF64B5F6),
    Color(0xFFBA68C8),
    Color(0xFFA1887F),
    Colors.white,
  ];
  static const _bgPalette = [
    Colors.white,
    Color(0xFFFFF8E1),
    Color(0xFFE3F2FD),
    Color(0xFFFCE4EC),
    Color(0xFF263238),
  ];

  void _onPanStart(DragStartDetails d) => setState(() {
        _current = Stroke(
          points: [d.localPosition],
          color: _color,
          width: _eraser ? _width * 3 : _width,
          isEraser: _eraser,
        );
      });

  void _onPanUpdate(DragUpdateDetails d) {
    if (_current == null) return;
    setState(() => _current = _current!.copyWith(points: [..._current!.points, d.localPosition]));
  }

  void _onPanEnd(DragEndDetails d) {
    if (_current == null) return;
    setState(() {
      _strokes.add(_current!);
      _current = null;
      _redoStack.clear();
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redoStack.add(_strokes.removeLast()));
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() => _strokes.add(_redoStack.removeLast()));
  }

  void _clear() => setState(() {
        _strokes.clear();
        _redoStack.clear();
        _current = null;
      });

  Future<Uint8List?> _exportPng({double pixelRatio = 3.0}) async {
    final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveToGallery() async {
    final bytes = await _exportPng();
    if (bytes == null) return;
    final ok = await saveImageBytes(bytes, 'grimpingpong_${DateTime.now().millisecondsSinceEpoch}.png');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '이미지를 저장했어요 🎉' : '저장 실패')),
    );
  }

  /// 전송: PNG → Storage 업로드 → Firestore 문서 생성.
  Future<void> _send() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('먼저 그림을 그려주세요 ✏️')));
      return;
    }
    setState(() => _sending = true);
    try {
      final bytes = await _exportPng();
      if (bytes == null) return;
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await DrawingService().sendDrawing(pngBytes: bytes, topic: widget.topic, date: date);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상대에게 전송했어요 💌')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Chip(avatar: const Text('🎨'), label: Text(widget.topic, overflow: TextOverflow.ellipsis)),
        actions: [
          IconButton(onPressed: _saveToGallery, icon: const Icon(Icons.download), tooltip: '이미지 저장'),
          if (!widget.localOnly)
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(onPressed: _send, icon: const Icon(Icons.send), tooltip: '상대에게 전송'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      painter: DrawingPainter(strokes: _strokes, current: _current, background: _bg),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _Toolbar(
            palette: _palette,
            bgPalette: _bgPalette,
            selectedColor: _color,
            selectedBg: _bg,
            width: _width,
            eraser: _eraser,
            onColor: (c) => setState(() {
              _color = c;
              _eraser = false;
            }),
            onBg: (c) => setState(() => _bg = c),
            onWidth: (w) => setState(() => _width = w),
            onEraser: () => setState(() => _eraser = !_eraser),
            onUndo: _undo,
            onRedo: _redo,
            onClear: _clear,
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final List<Color> palette, bgPalette;
  final Color selectedColor, selectedBg;
  final double width;
  final bool eraser;
  final ValueChanged<Color> onColor, onBg;
  final ValueChanged<double> onWidth;
  final VoidCallback onEraser, onUndo, onRedo, onClear;

  const _Toolbar({
    required this.palette,
    required this.bgPalette,
    required this.selectedColor,
    required this.selectedBg,
    required this.width,
    required this.eraser,
    required this.onColor,
    required this.onBg,
    required this.onWidth,
    required this.onEraser,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
  });

  Widget _swatch(Color c, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.blueAccent : Colors.grey.shade300,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: palette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) =>
                    _swatch(palette[i], !eraser && palette[i] == selectedColor, () => onColor(palette[i])),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('배경 ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ...bgPalette.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _swatch(c, c == selectedBg, () => onBg(c)),
                    )),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.brush, size: 18),
                Expanded(child: Slider(min: 1, max: 24, value: width, onChanged: onWidth)),
                IconButton(onPressed: onEraser, isSelected: eraser, icon: const Icon(Icons.cleaning_services_outlined)),
                IconButton(onPressed: onUndo, icon: const Icon(Icons.undo)),
                IconButton(onPressed: onRedo, icon: const Icon(Icons.redo)),
                IconButton(onPressed: onClear, icon: const Icon(Icons.delete_outline)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
