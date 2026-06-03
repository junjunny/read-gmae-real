// 프로필 사진 선택 facade.
// - 웹: <input type=file> + 캔버스 리사이즈(브라우저가 디코딩 → HEIC 등도 OK)
// - 모바일: image_picker
// image_picker의 웹 구현이 런타임에 등록되지 않아 pickImage가
// MissingPluginException을 내던 문제를 우회한다.
export 'image_pick_io.dart'
    if (dart.library.js_interop) 'image_pick_web.dart';
