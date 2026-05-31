import 'package:firebase_auth/firebase_auth.dart';

/// ID(생일) + 비밀번호 기반 인증.
/// 이메일은 ID로부터 생성(0421 → 0421@jhs.app). 비밀번호는 앱에 저장되지 않는다.
class AuthService {
  final _auth = FirebaseAuth.instance;

  static String emailFor(String id) => '$id@jhs.app';

  String? get currentId {
    final email = _auth.currentUser?.email;
    if (email == null) return null;
    return email.split('@').first;
  }

  /// 처음이면 계정 생성(=비번 설정), 이미 있으면 로그인(=비번 검증).
  Future<void> loginOrRegister(String id, String password) async {
    final email = emailFor(id);
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // 기존 계정 → 비밀번호로 로그인 (틀리면 예외)
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        rethrow;
      }
    }
  }

  Future<void> signOut() => _auth.signOut();
}
