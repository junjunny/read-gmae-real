// 플랫폼별 이미지 저장 facade.
// - 웹: 브라우저 다운로드(Blob)
// - 모바일: 사진첩 저장(saver_gallery)
export 'image_export_io.dart'
    if (dart.library.js_interop) 'image_export_web.dart';
