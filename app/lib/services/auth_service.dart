import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_session.dart';

/// 이메일/비밀번호 인증.
/// 요구사항 4(기기 변경 시 데이터 유지)를 위해 익명이 아닌 계정 기반으로 구현.
class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get current => _auth.currentUser;

  Future<void> signUp(String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _db.collection('users').doc(cred.user!.uid).set({
      'displayName': displayName.trim(),
      'coupleId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    AppSession.instance.clear();
  }

  /// 로그인 후 users 문서를 읽어 세션을 채운다.
  Future<void> loadSession() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    AppSession.instance
      ..uid = user.uid
      ..displayName = data['displayName'] ?? '익명'
      ..coupleId = data['coupleId'];
  }
}
