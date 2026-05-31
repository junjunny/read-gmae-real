import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'home_shell.dart';
import 'pairing_screen.dart';

/// 로그인 상태 → 페어링 상태에 따라 분기하는 최상위 게이트.
class AuthGate extends StatelessWidget {
  AuthGate({super.key});
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authState,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        if (!snap.hasData) {
          return const AuthScreen(); // 미로그인
        }
        // 로그인됨 → 세션 로드 후 페어링 여부 확인
        return FutureBuilder(
          future: _auth.loadSession(),
          builder: (context, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            return AppSession.instance.isPaired
                ? const HomeShell()
                : const PairingScreen();
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
