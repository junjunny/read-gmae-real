import 'package:firebase_messaging/firebase_messaging.dart';

import 'points_service.dart';
import 'session_prefs.dart';

/// 웹 푸시(FCM) 권한 요청 + 토큰 저장.
class PushService {
  /// 알림 켜기: 권한 요청 → 토큰 발급 → Firestore 저장. 결과 메시지 반환.
  static Future<String> enable() async {
    final svc = PointsService();
    final vapid = await svc.getVapidKey();
    if (vapid == null || vapid.isEmpty) return '설정이 아직 없어요(잠시 후 재시도).';
    final m = FirebaseMessaging.instance;
    final settings = await m.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return '알림 권한이 거부됐어요. 브라우저 설정에서 허용해주세요.';
    }
    final token = await m.getToken(vapidKey: vapid);
    if (token == null) return '토큰 발급 실패(아이폰은 홈 화면에 추가 후 시도).';
    await svc.saveToken(SessionPrefs.userId ?? '0421', token);
    return 'ok';
  }
}
