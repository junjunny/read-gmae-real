import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

/// 모바일: 사진첩에 PNG 저장.
Future<bool> saveImageBytes(Uint8List bytes, String fileName) async {
  if (await Permission.photos.isDenied) {
    await Permission.photos.request();
  }
  final result = await SaverGallery.saveImage(
    bytes,
    fileName: fileName,
    androidRelativePath: 'Pictures/그림핑퐁',
    skipIfExists: false,
  );
  return result.isSuccess;
}
