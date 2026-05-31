import 'package:shared_preferences/shared_preferences.dart';

/// 로컬 세션: 본인 ID(생일) + 방 코드 + 프로필 이미지(base64).
/// 로그인 없이 ID로 신원/포인트를 구분, 같은 초대코드로 같은 방에 연결.
class SessionPrefs {
  static String? userId; // 0421 / 0118
  static String? roomId; // 초대코드 (0516)
  static String? profileB64; // 프로필 이미지(PNG/JPG) base64, 없으면 null

  static const _kUser = 'user_id';
  static const _kRoom = 'room_id';
  static const _kProfile = 'profile_b64';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      userId = p.getString(_kUser);
      roomId = p.getString(_kRoom);
      profileB64 = p.getString(_kProfile);
    } catch (_) {}
  }

  static Future<void> save({required String userId, required String roomId}) async {
    SessionPrefs.userId = userId;
    SessionPrefs.roomId = roomId;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kUser, userId);
      await p.setString(_kRoom, roomId);
    } catch (_) {}
  }

  static Future<void> setProfile(String b64) async {
    profileB64 = b64;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kProfile, b64);
    } catch (_) {}
  }

  static Future<void> clear() async {
    userId = null;
    roomId = null;
    profileB64 = null;
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kUser);
      await p.remove(_kRoom);
      await p.remove(_kProfile);
    } catch (_) {}
  }
}
