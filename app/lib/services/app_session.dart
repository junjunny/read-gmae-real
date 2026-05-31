/// 앱 전역에서 공유하는 현재 사용자/커플 세션 정보.
/// 별도 상태관리 패키지 없이 간단한 싱글턴으로 유지(경량).
class AppSession {
  AppSession._();
  static final AppSession instance = AppSession._();

  String? uid;
  String? displayName;
  String? coupleId;

  bool get isPaired => coupleId != null;

  void clear() {
    uid = null;
    displayName = null;
    coupleId = null;
  }
}
