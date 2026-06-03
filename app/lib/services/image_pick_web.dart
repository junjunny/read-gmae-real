import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// 웹: <input type=file>로 사진을 고른 뒤, 브라우저로 디코딩하고 캔버스에서
/// 최대 400px·JPEG(품질 0.8)로 줄여 바이트를 반환한다.
/// - 브라우저가 디코딩하므로 HEIC 등 어떤 폰 사진이든 호환.
/// - 작게 줄이므로 Firestore 1MB 문서 제한도 안전.
/// 취소하면 완료되지 않을 수 있으나 UI를 막지 않는다.
Future<Uint8List?> pickImageBytes() {
  final completer = Completer<Uint8List?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';

  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      completer.complete(null);
      return;
    }
    final url = web.URL.createObjectURL(file);
    final img = web.HTMLImageElement();
    img.onload = (web.Event _) {
      try {
        const maxSide = 400.0;
        var tw = img.naturalWidth.toDouble();
        var th = img.naturalHeight.toDouble();
        final longest = tw > th ? tw : th;
        if (longest > maxSide) {
          final s = maxSide / longest;
          tw *= s;
          th *= s;
        }
        final canvas = web.HTMLCanvasElement()
          ..width = tw.round()
          ..height = th.round();
        final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
        ctx.drawImage(img, 0, 0, tw, th);
        web.URL.revokeObjectURL(url);
        final dataUrl = canvas.toDataURL('image/jpeg', 0.8.toJS);
        final comma = dataUrl.indexOf(',');
        final b64 = comma >= 0 ? dataUrl.substring(comma + 1) : dataUrl;
        if (!completer.isCompleted) completer.complete(base64Decode(b64));
      } catch (_) {
        web.URL.revokeObjectURL(url);
        if (!completer.isCompleted) completer.complete(null);
      }
    }.toJS;
    img.onerror = (web.Event _) {
      web.URL.revokeObjectURL(url);
      if (!completer.isCompleted) completer.complete(null);
    }.toJS;
    img.src = url;
  }.toJS;

  web.document.body?.appendChild(input);
  input.click();
  completer.future.whenComplete(() {
    if (input.isConnected) input.remove();
  });
  return completer.future;
}
