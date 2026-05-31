import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/stroke.dart';
import '../services/image_export.dart';
import '../widgets/drawing_painter.dart';

/// 메인 캔버스. 그리기 + 저장 + (선택)제출.
/// 이 화면은 항상 push로 진입하므로 AppBar 뒤로가기가 정상 동작한다.
class CanvasScreen extends StatefulWidget {
  final String topic;

  /// 제출 콜백. null이면 제출 버튼을 숨긴다(순수 로컬 그리기).
  /// PNG 바이트를 받아 업로드 등을 수행하고, 성공 시 true 반환.
  final Future<bool> Function(Uint8List png)? onSubmit;

  const CanvasScreen({super.key, required this.topic, this.onSubmit});

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
  bool _submitting = false;

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

  Future<void> _confirmClear() async {
    if (_strokes.isEmpty && _redoStack.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('전체 지우기'),
        content: const Text('그린 그림을 모두 지울까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('지우기')),
        ],
      ),
    );
    if (ok == true) _clear();
  }

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

  Future<void> _submit() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('먼저 그림을 그려주세요 ✏️')));
      return;
    }
    setState(() => _submitting = true);
    try {
      // 제출본은 Firestore 문서 용량(1MB) 내 + 빠른 전송을 위해 해상도를 낮춰 내보냄
      final bytes = await _exportPng(pixelRatio: 1.5);
      if (bytes == null) return;
      final ok = await widget.onSubmit!(bytes);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제출 완료! 상대에게 공유됐어요 💌')));
        Navigator.of(context).pop(true); // 제출 후 자동으로 뒤로
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('제출 실패 — 잠시 후 다시 시도해주세요')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('제출 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        // 명시적 뒤로가기 (push로 진입하므로 항상 동작)
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Chip(avatar: const Text('🎨'), label: Text(widget.topic, overflow: TextOverflow.ellipsis)),
        actions: [
          IconButton(onPressed: _saveToGallery, icon: const Icon(Icons.download), tooltip: '이미지 저장'),
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
            onClear: _confirmClear,
          ),
        ],
      ),
      // 제출 버튼: onSubmit이 있을 때만
      bottomNavigationBar: widget.onSubmit == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: Text(_submitting ? '제출 중...' : '제출하고 공유하기'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
              ),
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
    return Container(
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
          // 굵기 슬라이더 (전용 줄 — 버튼과 안 겹치게)
          Row(
            children: [
              const Icon(Icons.brush, size: 18),
              Expanded(child: Slider(min: 1, max: 24, value: width, onChanged: onWidth)),
            ],
          ),
          // 액션 버튼 (큼직하게, 균등 배치)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionBtn(icon: Icons.cleaning_services_outlined, label: '지우개', active: eraser, onTap: onEraser),
              _ActionBtn(icon: Icons.undo, label: '되돌리기', onTap: onUndo),
              _ActionBtn(icon: Icons.redo, label: '다시', onTap: onRedo),
              _ActionBtn(icon: Icons.delete_outline, label: '전체삭제', onTap: onClear),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? Theme.of(context).colorScheme.primary : Colors.black87;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
