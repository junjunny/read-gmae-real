import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/canvas_screen.dart';

/// Firebase 연결 성공 여부. 실패하면 로컬 모드(캔버스만)로 동작.
bool firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
  } catch (_) {
    // firebase_options.dart가 자리표시자이거나 설정 전 → 로컬 모드
    firebaseReady = false;
  }
  await initializeDateFormatting('ko');
  runApp(const GrimPingPongApp());
}

class GrimPingPongApp extends StatelessWidget {
  const GrimPingPongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '그림핑퐁',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFFF6F91)),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: firebaseReady ? AuthGate() : const _LocalModeHome(),
    );
  }
}

/// Firebase 미설정 시 진입점: 캔버스 + 안내 배너.
class _LocalModeHome extends StatelessWidget {
  const _LocalModeHome();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.amber.shade100,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '로컬 모드: 그리기·저장만 됩니다. Firebase 연결 시 매일 주제·공유·히스토리가 켜져요.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Expanded(child: CanvasScreen(localOnly: true, topic: '자유롭게 그려보세요 🎨')),
      ],
    );
  }
}
